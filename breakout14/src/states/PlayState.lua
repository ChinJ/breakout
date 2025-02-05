--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = {params.ball}
    self.level = params.level

    self.recoverPoints = 5000
    self.paddleGrowPoints = params.paddleGrowPoints
    
    -- there can only be 1 power up at a time
    self.powerUp = nil
    self.timer = 0
    self.powerUpTimer = math.random(10, 15)
    
    -- locked bricks related
    self.hasLockedBricks = self:hasLockedBricks() -- store it to avoid loop multiple times
    self.hasKey = false
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    for k, ball in pairs(self.balls) do
        ball:update(dt)
    end

    -- spawn power up after certain time if no powerup exists
    self.timer = self.timer + dt
    if self.timer > self.powerUpTimer then
        if self.powerUp == nil then
            local min = self:onlyLockedBricksLeft() and 10 or 9
            local max = self.hasLockedBricks and 10 or 9
            local type = math.random(min, max)
            self.powerUp = PowerUp(type)
            
            self.timer = 0
        end
    end

    -- update of powerup exists
    if self.powerUp ~= nil then 
        self.powerUp:update(dt)

        local deletePowerUp = false
        if self.powerUp:collides(self.paddle) then
            if self.powerUp.type == 9 then
                gSounds['powerup-balls']:stop()
                gSounds['powerup-balls']:play()
                table.insert(self.balls, Ball(self.balls[1].skin, self.balls[1].x, self.balls[1].y))
                table.insert(self.balls, Ball(self.balls[1].skin, self.balls[1].x, self.balls[1].y))
            elseif self.powerUp.type == 10 then
                gSounds['powerup-key']:stop()
                gSounds['powerup-key']:play()
                self.hasKey = true
                self.hasLockedBricks = false
            end
            deletePowerUp = true
        end

        if self.powerUp.y > VIRTUAL_HEIGHT then
            deletePowerUp = true
        end

        -- remove powerup if collides with paddle or cross the lower window boundary
        if deletePowerUp then
            self.powerUp = nil
        end
    end

    -- check collision with paddle for every ball
    for k, ball in pairs(self.balls) do
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy
    
            --
            -- tweak angle of bounce based on where it hits the paddle
            --
    
            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end
    
            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with every ball
    for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick.inPlay then
            if brick:isLockedBrick() and self.hasKey then
                brick:unlockBrick()
            end

            for k, ball in pairs(self.balls) do
                if ball:collides(brick) then

                    -- add to score
                    self.score = self.score + brick:score()--(brick.tier * 200 + brick.color * 25)
                    self.paddleGrowPoints = self.paddleGrowPoints + brick:score()--(brick.tier * 200 + brick.color * 25)

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()

                    -- if we have enough points, recover a point of health
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health
                        self.health = math.min(3, self.health + 1)

                        -- multiply recover points by 2
                        self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end

                    -- paddle will grow if accumulated points is more than threshold, scale with level
                    if self.paddleGrowPoints > (PADDLE_GROW_THRESHOLD * self.level) then
                        self.paddle:updateSize(true)
                        self.paddleGrowPoints = self.paddleGrowPoints % (PADDLE_GROW_THRESHOLD * self.level)
                    end

                    -- go to our victory screen if there are no more bricks left
                    if self:checkVictory() then
                        gSounds['victory']:play()

                        gStateMachine:change('victory', {
                            level = self.level,
                            paddle = self.paddle,
                            health = self.health,
                            score = self.score,
                            highScores = self.highScores,
                            ball = ball,
                            recoverPoints = self.recoverPoints
                        })
                    end

                    --
                    -- collision code for bricks
                    --
                    -- we check to see if the opposite side of our velocity is outside of the brick;
                    -- if it is, we trigger a collision on that side. else we're within the X + width of
                    -- the brick and should check to see if the top or bottom edge is outside of the brick,
                    -- colliding on the top or bottom accordingly 
                    --

                    -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                    -- so that flush corner hits register as Y flips, not X flips
                    if ball.x + 2 < brick.x and ball.dx > 0 then
                        
                        -- flip x velocity and reset position outside of brick
                        ball.dx = -ball.dx
                        ball.x = brick.x - 8
                    
                    -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                    -- so that flush corner hits register as Y flips, not X flips
                    elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                        
                        -- flip x velocity and reset position outside of brick
                        ball.dx = -ball.dx
                        ball.x = brick.x + 32
                    
                    -- top edge if no X collisions, always check
                    elseif ball.y < brick.y then
                        
                        -- flip y velocity and reset position outside of brick
                        ball.dy = -ball.dy
                        ball.y = brick.y - 8
                    
                    -- bottom edge if no X collisions or top collision, last possibility
                    else
                        
                        -- flip y velocity and reset position outside of brick
                        ball.dy = -ball.dy
                        ball.y = brick.y + 16
                    end

                    -- slightly scale the y velocity to speed up the game, capping at +- 150
                    if math.abs(ball.dy) < 150 then
                        ball.dy = ball.dy * 1.02
                    end

                    -- only allow colliding with one brick, for corners
                    break
                end
            end
        end
    end

    -- only minus health if the last ball is lost
    for k, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            table.remove(self.balls, k)

            if next(self.balls) == nil then
                self.health = self.health - 1
                gSounds['hurt']:play()
                self.paddle:updateSize(false)

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints,
                        paddleGrowPoints = self.paddleGrowPoints
                    })
                end
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    -- quit game
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    -- render multiple balls
    for k, ball in pairs(self.balls) do
        ball:render()
    end

    -- only render if powerup exists
    if self.powerUp ~= nil then 
        self.powerUp:render() 
    end

    if self.hasKey then
        love.graphics.draw(gTextures['key'], gFrames['key'][1], VIRTUAL_WIDTH - 100 - 17, 6)
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- debug purpose
    -- love.graphics.printf(tostring(self.paddleGrowPoints), 0, VIRTUAL_HEIGHT / 2, VIRTUAL_WIDTH, 'center')

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

--[[
    check if player has won - victory achieve when no more bricks in play
]]
function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

--[[
    Check if current level has any locked bricks
]]
function PlayState:hasLockedBricks()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay and brick:isLockedBrick() then
            return true
        end
    end

    return false
end

--[[
    Check if only locked bricks are left
]]
function PlayState:onlyLockedBricksLeft()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay and brick:isLockedBrick() == false then
            return false
        end
    end

    return true
end
--[[
    -- PowerUp Class --
    Author: Jeah Lune Chin
    jeahlune91@gmail.com

    Represents a power up class in the world space that
    the paddle can collide and receive a power depends on
    the types of power up.
]]

PowerUp = Class{}

function PowerUp:init(type)
    -- power up types
    self.type = type

    self.x = math.random(50 + 16, VIRTUAL_WIDTH - 50 - 16)
    self.y = VIRTUAL_HEIGHT/2
    self.width = 16
    self.height = 16

    self.dy = 20 -- always goes down
end

function PowerUp:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

function PowerUp:update(dt)
    self.y = self.y + self.dy * dt
end

function PowerUp:render(dt)
    love.graphics.draw(gTextures['main'],
        gFrames['powerUps'][self.type],
        self.x, self.y)
end
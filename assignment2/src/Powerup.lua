Powerup = Class{}

-- some of the colors in our palette (to be used with particle systems)
local paletteColors = {
    -- blue
    [1] = {
        ['r'] = 0.388,
        ['g'] = 0.608,
        ['b'] = 1
    },
    -- green
    [2] = {
        ['r'] = 0.416,
        ['g'] = 0.745,
        ['b'] = 0.184
    },
    -- red
    [3] = {
        ['r'] = 0.851,
        ['g'] = 0.341,
        ['b'] = 0.388
    },
    -- purple
    [4] = {
        ['r'] = 0.843,
        ['g'] = 0.482,
        ['b'] = 0.729
    },
    -- gold
    [5] = {
        ['r'] = 0.984,
        ['g'] = 0.949,
        ['b'] = 0.212
    }
}

function Powerup:init(brickX, brickY, skin, color)
    self.width = 16
    self.height = 16

    self.x = brickX
    self.y = brickY
    self.dx = 0
    self.dy = 30

    self.falling = true
    self.isCaught = false
    self.isActive = false

    self.psystem = love.graphics.newParticleSystem(gTextures['particle'], 10)
    self.psystem:setParticleLifetime(0.5, 1)
    self.psystem:setLinearAcceleration(-15, 0, 15, 80)
    self.psystem:setEmissionArea('borderellipse', 10, 10)
    self.color = color

    self.skin = skin
end

function Powerup:update(dt)
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt
    self.psystem:update(dt)
end

function Powerup:log()
    print('I am powerup!')
    print('At location x: ' .. self.x .. ' y: ' .. self.y)
    print('Skin number: ' .. self.skin)
    print('Caught: ' .. tostring(self.isCaught))
end

function Powerup:render()
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.skin], self.x + 8, self.y)
end

function Powerup:renderParticles()
    love.graphics.draw(self.psystem, self.x + 16, self.y + 8)
end

function Powerup:emitParticles()
    self.psystem:setColors(
            paletteColors[self.color].r,
            paletteColors[self.color].g,
            paletteColors[self.color].b,
            55,
            paletteColors[self.color].r,
            paletteColors[self.color].g,
            paletteColors[self.color].b,
            0
        )

    self.psystem:emit(10)
    -- self.falling = false
end

function Powerup:collides(target)
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
    self.isCaught = true
    return true
end
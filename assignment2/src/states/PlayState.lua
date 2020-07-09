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

-- create powerups table to hold active powers ups only

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
    self.ball = params.ball
    self.balls = params.balls
    self.level = params.level
    self.levelLocked = false
    self.powerups = {}
    self.keySpawned = false
    self.keyActive = false
    self.growPoints = params.growPoints
    self.recoverPoints = params.recoverPoints
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
    
    for b, ball in pairs(self.balls) do
        ball:update(dt)
    end
    
    if #self.balls <= 1 then
        powerupActive = false
    end

    for b, ball in pairs(self.balls) do
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

        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)
                if brick.isLocked and not brick.keyActive then
                    self.score = self.score
                elseif brick.isLocked and brick.keyActive then
                    self.score = self.score + self.level * 1000
                end

                if math.random( 10 ) < 2 then
                    self.powerup = Powerup(brick.x, brick.y, 7, brick.color)
                    table.insert(self.powerups, self.powerup)
                end
                
                if math.random( 30 ) < 4 and self.levelLocked and not self.keySpawned 
                                        and not self.keyActive and not brick.keyActive then
                    self.powerup = Powerup(brick.x, brick.y, 10, brick.color)
                    self.powerup.isKey = true
                    self.keySpawned = true
                    table.insert(self.powerups, self.powerup)
                end

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints + math.min(25000, self.recoverPoints)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                if self.score > self.growPoints then
                    self.paddle:grow(self.paddle.size)
                    gSounds['grow']:play()
                    self.growPoints = self.growPoints + math.min(10000, self.growPoints)
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
                        balls = self.balls,
                        recoverPoints = self.recoverPoints,
                        growPoints = self.growPoints
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

        -- if ball goes below bounds, revert to serve state and decrease health
        if powerupActive and ball.y >= VIRTUAL_HEIGHT then
            table.remove(self.balls, b)
            gSounds['hurt']:play()
        elseif #self.balls == 1 and ball.y >= VIRTUAL_HEIGHT then
            self.health = self.health - 1
            --self.powerups = {}
            powerupActive = false
            gSounds['hurt']:play()
            table.remove(self.balls, b)
            self.paddle:shrink(self.paddle.size)

            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    balls = self.balls,
                    ball = self.ball,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints,
                    growPoints = self.growPoints
                })
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
        if brick.isLocked then
            self.levelLocked = true
        end
    end
    
    if self.powerup then
        for p, powerup in pairs(self.powerups) do
            powerup:update(dt)
            if powerup:collides(self.paddle) then
                if powerup.isKey then
                    self.keySpawned = false
                    self.keyActive = true
                    for b, brick in pairs(self.bricks) do
                        brick.keyActive = true
                    end
                end
                table.remove( self.powerups, p )
                if not powerupActive and not powerup.isKey then
                    self.ball = Ball(self.paddle.x, self.paddle.width, self.balls[1].skin)
                    table.insert(self.balls, self.ball)
                    self.ball = Ball(self.paddle.x, self.paddle.width, self.balls[1].skin)
                    table.insert(self.balls, self.ball)
                    powerupActive = true
                end
            end
        end
    end


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

    for b, ball in pairs(self.balls) do
        ball:render()
    end
    
    if self.powerup then
        if self.powerup.falling then
            for p, powerup in pairs(self.powerups) do
            powerup:render()
            powerup:renderParticles()
            powerup:emitParticles()
        end
        if self.powerup.y > 230 then
            self.powerup.falling = false
            if self.powerup.isKey then
                self.keySpawned = false
            end
            table.remove( self.powerups, 1 )
        end
    end
end

    self.paddle:render()

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end
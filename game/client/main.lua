-- package.path = package.path .. ";../?.lua"
-- package.path = package.path .. ";../?/init.lua"

local game = require "game"
local zombie = require "zombie"
local player = require "player"

function love.load()
    love.window.setFullscreen(true)
    GameClient = game.newClient(22122)
    love.window.setTitle( "Client")

    Sprites = {}
    Sprites.background = love.graphics.newImage('sprites/background.png')
    Sprites.bullet = love.graphics.newImage('sprites/bullet.png')
    Sprites.player = love.graphics.newImage('sprites/player1.png')
    Sprites.extra = love.graphics.newImage('sprites/ext.png')
    Sprites.zombie = love.graphics.newImage('sprites/zombie.png')
    
    Fonts = {}
    Fonts.xs = love.graphics.newFont(15)
    Fonts.s = love.graphics.newFont(20)
    Fonts.m = love.graphics.newFont(25)
    Fonts.l = love.graphics.newFont(30)

    -- setup a local player for offline play
    player.reset(GameClient.player)
    GameClient.player.name = 'Player_1'
    GameClient.player.id = 'id'
    GameClient.players['id'] = GameClient.player
end


function love.update(dt)
    GameClient:update(dt)
end

function love.draw()

    -- uncomment for debug, also comment background then
    -- GameClient.world:draw()

    -- drawing shapes first
    love.graphics.setColor(1, 1, 1, 1) -- white

    -- background
    love.graphics.draw(Sprites.background, 0, 0)
    
    -- all players
    if GameClient.currentGameState ~= GameClient.states.GAME_END then
        for id, playerObj in pairs(GameClient.players) do
            local spriteObj = Sprites.extra
            local angle = playerObj.angle
            local x = playerObj.x
            local y = playerObj.y
            if playerObj.id == GameClient.player.id then
                spriteObj = Sprites.player
                angle = GameClient.player.angle
                x = GameClient.player.x
                y = GameClient.player.y
            end
            love.graphics.draw(spriteObj,x, y, angle, 2, 2, spriteObj:getWidth()/2, spriteObj:getHeight()/2)
        end
    end

    -- extra
    for i,z in ipairs(GameClient.zombies) do
        love.graphics.draw(Sprites.zombie, z.x, z.y, zombie.playerAngle(z), nil, nil, Sprites.zombie:getWidth()/2, Sprites.zombie:getHeight()/2)
    end

    for i,b in ipairs(GameClient.bullets) do
        love.graphics.draw(Sprites.bullet, b.x, b.y, nil, 0.5, 0.5, Sprites.bullet:getWidth()/2, Sprites.bullet:getHeight()/2)
    end
    ------------------------------------------------------------------------
    -- drawing text now

    love.graphics.setColor(0, 0, 0, 1) -- black

    -- player information
    if GameClient.client then
        love.graphics.printf("Name: " .. GameClient.player.name, Fonts.xs, 10, 10, love.graphics.getWidth(), "left") 
        love.graphics.printf("RTT: " .. GameClient.client:getRoundTripTime(), Fonts.xs, -10, 10, love.graphics.getWidth(), "right") 
        love.graphics.printf("Server: " .. GameClient.client:getAddress(), Fonts.xs, -10, 30, love.graphics.getWidth(), "right") 
    end

    -- text according to game states
    if GameClient.currentGameState == GameClient.states.CLIENT_PLAY then
        love.graphics.printf("Finding server ...", Fonts.l, 0, 50, love.graphics.getWidth(), "center")
    end
    if GameClient.currentGameState == GameClient.states.INIT then
        love.graphics.printf("Press spacebar to begin!", Fonts.l, 0, 50, love.graphics.getWidth(), "center")
    end
    if GameClient.currentGameState == GameClient.states.WAITING then
        love.graphics.printf("Ready! Waiting for other players", Fonts.l, 0, 50, love.graphics.getWidth(), "center")
    end
    if GameClient.player.score and
        (GameClient.currentGameState == GameClient.states.READY
        or GameClient.currentGameState == GameClient.states.CLIENT_PLAY) then
        love.graphics.printf("Score: " .. GameClient.player.score, Fonts.l, 10, love.graphics.getHeight()-100, love.graphics.getWidth(), "center")
        love.graphics.printf("Bullets: " .. GameClient.player.bulletsFired, Fonts.xs, 10, love.graphics.getHeight()-50, love.graphics.getWidth(), "left")
        love.graphics.printf("Accuracy: " .. string.format("%.2f %%",  GameClient.player.accuracy), Fonts.xs, 10, love.graphics.getHeight()-30, love.graphics.getWidth(), "left")
    end
    if GameClient.player.score and GameClient.currentGameState == GameClient.states.GAME_END then
        love.graphics.printf("Game over! Press spacebar to restart!", Fonts.l, 0, 50, love.graphics.getWidth(), "center")
        love.graphics.printf("Scores: ", Fonts.m, 20, love.graphics.getHeight()-250, love.graphics.getWidth(), "left")
        local height = 200
        local zombiesKilled = 0
        local sortedByScore = {}
        for id, playerObj in pairs(GameClient.playersClientCopy) do
            zombiesKilled = zombiesKilled + playerObj.score
            table.insert(sortedByScore, {id, playerObj})
        end
        table.sort(sortedByScore, function(a, b) return a[2].score > b[2].score end)
        for _, v in pairs(sortedByScore) do
            local playerObj = v[2]
            if playerObj.id == GameClient.player.id then love.graphics.setColor(0.2, 0.2, 0.8, 1) end
            love.graphics.printf(playerObj.name .. " :: Zombies killed: " .. playerObj.score .. ", Accuracy: " .. string.format("%.2f %%",  playerObj.accuracy), Fonts.s ,20, love.graphics.getHeight()-height, love.graphics.getWidth(), "left")
            love.graphics.setColor(0, 0, 0, 1)
            height = height - 30
        end
        love.graphics.printf("Total zombies killed : " .. zombiesKilled, Fonts.m, 0, 100, love.graphics.getWidth(), "center")
    end
    if GameClient.currentGameState == GameClient.states.SERVER_DISCONNECT then
        love.graphics.printf("Disconnected from server.. Game will close soon!", Fonts.l, 0, 50, love.graphics.getWidth(), "center")
    end
    love.graphics.printf("Press escape to quit", Fonts.xs, 0, 5, love.graphics.getWidth(), "center")
end

function love.keypressed(key)
    if key == "space" then
        if GameClient.client then
            GameClient.client:send("input", {
                timestamp = love.timer.getTime(),
            })
        else
            if GameClient.currentGameState == GameClient.states.GAME_END then
                GameClient:resetGame()
                GameClient.currentGameState = GameClient.states.CLIENT_PLAY
            end
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

function love.keyreleased(key)
   if key == "w" or key == "a" or key == "s" or key == "d" then
      GameClient.player.direction = 'neutral'
   end
end

function love.quit()
    print("Thanks for playing!")
    if GameClient.client then
        GameClient.client:disconnectNow()
    end
end
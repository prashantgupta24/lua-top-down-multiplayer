local socket = require "socket"
local sock = require "libraries.sock"

require "util"
local zombie = require "zombie"
local bullet = require "bullet"
local player = require "player"

local game = {}

local GameServer = {}

local multicastAddress = "225.0.0.37" -- random multicast address
local startingZombieSpawnTime = 2

local gameStates =  {
    CLIENT_PLAY = 'CLIENT_PLAY',
    INIT = 'INIT',
    WAITING = 'WAITING',
    READY = 'READY',
    PARTIAL_DEAD = 'PARTIAL_DEAD', -- todo
    GAME_END = 'GAME_END',
    SERVER_DISCONNECT = 'SERVER_DISCONNECT'
}

local gameChannels = {
    GAME_UPDATE_FROM_SERVER = "game_update_from_server",
    GAME_STATE = "game_state",
    CONNECT = "connect",
    CONFIG = "config",
    JOIN = "join",
    JOIN_RECEIVED = "join_rec",
    INPUT = "input",
    CLICK = "click",
    GAME_UPDATE_FROM_CLIENT = "game_update_from_client",
    DISCONNECT = "disconnect"
}

function GameServer:resetGame()
    ResetGameOnStart(self)
    
    self:sendToAll(gameChannels.GAME_UPDATE_FROM_SERVER, {
        players = self.players,
        bullets = self.bullets,
        zombies = self.zombies,
        movement = true
    })
    print('game reset!')
end

function GameServer:sendGameState()
    self:sendToAll(gameChannels.GAME_STATE, {
        currentGameState = self.currentGameState
    })
end

local function spawnZombieTimer(server, dt)
    server.timer = server.timer - dt
    if server.timer <= 0 then
        zombie.spawn(server)
        server.maxTime = 0.98 * server.maxTime
        server.timer = server.maxTime
    end
end

local advertiseVal = 0
local serverUpdateTimeVal = 0
function GameServer:update(dt)
    self.enetServer:update(dt)
    self.world:update(dt)

    serverUpdateTimeVal = serverUpdateTimeVal + dt

    if (serverUpdateTimeVal >= self.updateTime) then
        serverUpdateTimeVal = serverUpdateTimeVal - self.updateTime
        self:sendToAll(gameChannels.GAME_UPDATE_FROM_SERVER, {
            players = self.players,
            bullets = self.bullets,
            zombies = self.zombies,
        })
    end

    if self.currentGameState ~= self.states.READY then
        advertiseVal = advertiseVal + dt
        if advertiseVal >= self.advertiseTime then
            advertiseVal = advertiseVal - self.advertiseTime
            print('advertising')
            self:advertise()
        end
    end

    -- cleanup
    if self.currentGameState == self.states.SERVER_DISCONNECT then
        love.event.quit()
    end

    if self.currentGameState == self.states.GAME_END then
        self.players_ready = {}
        self.players_in_game = {}
        ResetValuesOnEnd(self)
        DestroyWorld(self.world)
    end

    if self.currentGameState == self.states.READY then
        spawnZombieTimer(self, dt)
        
        for id, playerObj in pairs(self.players) do
            player.move(self, playerObj)
        end

        for i,z in ipairs(self.zombies) do
            zombie.move(self, z, true, dt)
            if self.zombieCollider[z.id]:enter('player') then
                -- print('collision zp! ' , z.id)
                self.currentGameState = self.states.GAME_END
                self:sendGameState()
            end
        end
        zombie.cleanup(self)

        for _, b in ipairs(self.bullets) do
            bullet.move(self, b, true, dt)
        end
        bullet.cleanup(self)
    end
end

function GameServer:sendToAll(channel, data)
    self.enetServer:sendToAll(channel, data)
end

function GameServer:advertise()
    self.adServer:sendto("game", multicastAddress, 11111)
end

function GameServer:destroy()
    self.enetServer:destroy()
end

function GameServer:setupCallbacks()
    -- Called when someone connects to the server
    self.enetServer:on("connect", function(data, client)
        print('Client joined : ', client:getConnectId())
        self.currentGameState = self.states.INIT
        -- the only reason we cannot use getConnectId itself as
        -- the unique id is because on disconnect, getConnectId
        -- returns nil
        client.uniqueID = client:getConnectId()
        client:send(gameChannels.CONFIG, {
            updateTime = self.updateTime,
            currentGameState = self.currentGameState
        })
    end)

    self.enetServer:on(gameChannels.JOIN, function(data, client)
        print('Join received from client : ', client.uniqueID )
        local newPlayer = player.spawn(client:getIndex(), client.uniqueID)
        self.players[newPlayer.id] = newPlayer
        client:send(gameChannels.JOIN_RECEIVED, {
            player=newPlayer
        })
        print('Total number of players : ', GetMapSize(self.players))
    end)

    self.enetServer:on(gameChannels.INPUT, function(data, client)
        if self.currentGameState == self.states.INIT or
            self.currentGameState == self.states.WAITING or
            self.currentGameState == self.states.GAME_END then
            self.players_ready[client.uniqueID] = 1
            local players_ready_num = GetMapSize(self.players_ready)
            if players_ready_num == GetMapSize(self.players) then
                self:resetGame()
                self.currentGameState = self.states.READY
                CopyValues(self.players_ready, self.players_in_game)
                self:sendGameState()
            else
                self.currentGameState = self.states.WAITING
                client:send(gameChannels.GAME_STATE, {
                currentGameState = self.currentGameState
            })
            end
        end
    end)

    self.enetServer:on(gameChannels.CLICK, function(data, client)
        -- print('click received from client : ', client)
        if self.currentGameState == self.states.READY then
            local playerClicked = self.players[data.bullet.playerID]
            local bulletFired = data.bullet
            self.bulletNum = self.bulletNum + 1
            bulletFired.id = self.bulletNum
            bulletFired.speed = 500
            bulletFired.dead = false
            playerClicked.bulletsFired = playerClicked.bulletsFired + 1
            table.insert(self.bullets, bulletFired)
        end
    end)

        
    self.enetServer:on(gameChannels.GAME_UPDATE_FROM_CLIENT, function(data, client)
        -- print('player_update received from : ', client)
        if data.playerID and self.players[data.playerID] then
            local playerToUpdate = self.players[data.playerID]
            playerToUpdate.x = data.playerX
            playerToUpdate.y = data.playerY
            playerToUpdate.angle = data.playerAngle
        end
    end)

    self.enetServer:on(gameChannels.DISCONNECT, function(data, client)
        print('client disconnected! : ', client.uniqueID)
        local idDisconnected = client.uniqueID
        self.players[idDisconnected] = nil
        self.players_ready[idDisconnected] = nil
        self.players_in_game[idDisconnected] = nil
        if self.playerCollider[idDisconnected] then
            self.playerCollider[idDisconnected]:destroy()
        end
        print('Total number of players : ', GetMapSize(self.players))
        if GetMapSize(self.players) == 0 then
            self.currentGameState = self.states.GAME_END
            self:resetGame()
        end
    end)
end



-- Client
local GameClient = {}

function GameClient:searchForServer()
    print('searching for server')
    local data, ip, _ = self.adClient:receivefrom()
    -- print(adClient:receivefrom())
    if data == "game" then
        -- fresh start
        self:resetGame()
        DestroyWorld(self.world)
        self:setupConnectionToServer(ip)
        self.adClient:close() -- very important
    end
end

function GameClient:setAngle()
    self.angleIndex = (self.angleIndex + 1) % self.anglesMax
    self.angles[self.angleIndex] =  self:playerMouseAngle()
    local angleToCheck = self.angleIndex - self.angleLag

    if angleToCheck < 0 then
        angleToCheck = self.anglesMax - math.abs(angleToCheck)
    end

    local angle = self.angles[angleToCheck]
    -- print(angleIndex, angles[angleIndex], angleToCheck, angle)
    if angle then
        self.player.angle = angle
        if self.playerCollider[self.player.id] then
            self.playerCollider[self.player.id]:setAngle(angle)
        end
    else
        self.player.angle = self.angles[1]
    end
end

function GameClient:handlePlayerMovement(dt)
    if self.playerCollider[self.player.id] then
        local px, py =  self.playerCollider[self.player.id]:getPosition()
        if love.keyboard.isDown("d") and self.player.x < love.graphics.getWidth() then
            self.playerCollider[self.player.id]:setX(px + self.player.speed*dt)
            self.player.direction = 'right'
        end
        if love.keyboard.isDown("a") and self.player.x > 0 then
            self.playerCollider[self.player.id]:setX(px - self.player.speed*dt)
            self.player.direction = 'left'
        end
        if love.keyboard.isDown("w") and self.player.y > 0 then
            self.playerCollider[self.player.id]:setY(py - self.player.speed*dt)
            self.player.direction = 'up'
        end
        if love.keyboard.isDown("s") and self.player.y < love.graphics.getHeight() then
            self.playerCollider[self.player.id]:setY(py + self.player.speed*dt)
            self.player.direction = 'down'
        end
        --update afterwards
        self.player.x, self.player.y =  self.playerCollider[self.player.id]:getPosition()
     end
end

function GameClient:handleMouseClick()
    if love.mouse.isDown(1) then
        local currentTime = love.timer.getTime()
        local doFireBullet = false
        if self.player.lastBFired then
           if currentTime - self.player.lastBFired > self.bulletFiringRate then
                doFireBullet = true
           end
        else
            doFireBullet = true
        end
        if doFireBullet == true then
            self:spawnBullet()
            self.player.lastBFired = currentTime
        end
    end
end

function GameClient:setupConnectionToServer(hostAddress)
    if not self.client then
        self.hostIPFound = true
        self.client = sock.newClient(hostAddress, self.port)
        self.client:setSerialization(bitser.dumps, bitser.loads)

        -- Called when a connection is made to the server
        self.client:on(gameChannels.CONNECT, function(data, server)
            self.client:send("join", {
                timestamp = love.timer.getTime()
            })
        end)

        self.client:on(gameChannels.CONFIG, function(data, server)
            print('updateTime frequency received from server : ', data.updateTime)
            self.updateTime = data.updateTime
            self.currentGameState = data.currentGameState
        end)

        self.client:on(gameChannels.DISCONNECT, function(data, server)
            print('Disconnected from server')
            love.event.quit()
        end)

        self.client:on(gameChannels.JOIN_RECEIVED, function(data)
            self.player = data.player
            print('my player_id : ', self.player.id)
            love.window.setTitle( self.player.name)
        end)

        self.client:on(gameChannels.GAME_STATE, function(data)
            self.currentGameState = data.currentGameState
            print('currentGameState now : ', self.currentGameState)
            if self.currentGameState == self.states.READY then self:resetGame() end
        end)

        self.client:on(gameChannels.GAME_UPDATE_FROM_SERVER, function(data)
            -- print('received game update from server')
            if data.players then
                self.players = data.players
                if data.players[self.player.id] then
                    self.player.score = data.players[self.player.id].score
                    self.player.bulletsFired = data.players[self.player.id].bulletsFired
                    self.player.accuracy = data.players[self.player.id].accuracy
                end
            end
            if data.bullets then
                self.bullets = data.bullets
            end
            if data.zombies then
                self.zombies = data.zombies
            end
            if data.movement then
                if self.playerCollider[self.player.id] then
                    self.playerCollider[self.player.id]:setPosition(self.players[self.player.id].x, self.players[self.player.id].y)
                end
            end
        end)

        self.client:connect()
        print('connected to server : ', hostAddress)
    end
end

function GameClient:resetGame()
    ResetGameOnStart(self)
end

function GameClient:playerMouseAngle()
    return math.atan2( love.mouse.getY() - self.player.y, love.mouse.getX() - self.player.x )
end

function GameClient:distanceBetween(x1, y1, x2, y2)
    return math.sqrt( (x2 - x1)^2 + (y2 - y1)^2 )
end

function GameClient:spawnBullet()
    local newBullet = bullet.spawn(self, self.player)
    -- only for independent play
    if self.currentGameState == 'CLIENT_PLAY' then
        self.player.bulletsFired = self.player.bulletsFired + 1
        table.insert(self.bullets, newBullet)
    end
    if self.client then
        self.client:send("click", {
            timestamp = love.timer.getTime(),
            bullet = newBullet
        })
    end
end

local searchVal = 0
local updateTimeVal = 0
function GameClient:update(dt)
    self.world:update(dt)
    if self.client then
        self.client:update()
    end

    if not self.hostIPFound then
        searchVal = searchVal + dt
        if searchVal >= self.searchTime  then
            searchVal = searchVal - self.searchTime
            self:searchForServer()
        end
    end


    if self.currentGameState == self.states.GAME_END or
    self.currentGameState == self.states.SERVER_DISCONNECT then
        ResetValuesOnEnd(self)
        DestroyWorld(self.world)
        return
    end

    updateTimeVal = updateTimeVal + dt
    if self.client and updateTimeVal >= self.updateTime then
        updateTimeVal= updateTimeVal - self.updateTime
        self.client:send(gameChannels.GAME_UPDATE_FROM_CLIENT, {
            playerID = self.player.id,
            playerX = self.player.x,
            playerY = self.player.y,
            playerAngle = self.player.angle,
        })
    end

    if self.currentGameState == self.states.CLIENT_PLAY then
        spawnZombieTimer(self, dt)
    end
    
    self:setAngle()

    -- create colliders for all players
    for id, playerObj in pairs(self.players) do
        -- client manages its own collider itself, makes for smoother gameplay
        if playerObj.id == self.player.id then
            if not self.playerCollider[playerObj.id] then
                player.createCollider(self, playerObj)
            end
        else
            player.move(self, playerObj)
        end
    end

    --remove disconnected players' colliders
    for id, collider in pairs(self.playerCollider) do
        if not self.players[id] then
            if self.playerCollider[id] then
                collider:destroy()
                self.playerCollider[id] = nil
            end
        end
    end

    -- used to populate player scores even after other clients
    -- have disconnected from game on GAME_END
    self.playersClientCopy = self.players
    
    self:handlePlayerMovement(dt)
    self:handleMouseClick()

    for i,z in ipairs(self.zombies) do
        zombie.move(self, z, self.currentGameState == self.states.CLIENT_PLAY, dt)
        if self.currentGameState == self.states.CLIENT_PLAY then
            if self.zombieCollider[z.id] and
                self.zombieCollider[z.id]:enter('player') then
                -- print('collision zp! ' , z.id)
                self.currentGameState = self.states.GAME_END
            end
        end
        --else the client doesn't have to worry about collisions
    end
    if self.currentGameState == self.states.CLIENT_PLAY then zombie.cleanup(self) end

    for _, b in ipairs(self.bullets) do
        bullet.move(self, b, self.currentGameState == self.states.CLIENT_PLAY, dt)
    end
    if self.currentGameState == self.states.CLIENT_PLAY then bullet.cleanup(self) end

end

game.newClient = function (port)

    local adClient = assert(socket.udp4())
    assert(adClient:setoption("reuseport", true))
    assert(adClient:setsockname("*", 11111))
    assert(adClient:setoption("ip-add-membership", {multiaddr = multicastAddress, interface = "*"}))
    adClient:settimeout(0)

    local gc = setmetatable({
        client = nil,
        hostIPFound = false,
        currentGameState = gameStates.CLIENT_PLAY,

        port = port,
        world = SetupWorld(),
        angles = {},
        angleIndex = 0, -- the index at which the angle is read
        angleLag = 10,
        anglesMax = 1200,

        players = {},
        playersClientCopy = {},
        player = {},

        -- colliders
        playerCollider = {},
        zombieCollider = {},
        bulletCollider = {},

        startingZombieSpawnTime = startingZombieSpawnTime,
        maxTime = startingZombieSpawnTime,
        timer = startingZombieSpawnTime,

        zombies = {},
        zombieNum = 0,

        bullets = {},
        bulletNum = 0,
        bulletFiringRate = 0.3, -- one bullet per 0.5 seconds

        updateTime=1/30,

        searchTime = 1,
        adClient = adClient,

        states = gameStates,
    }, {__index = GameClient})
    
    return gc
end

game.newServer = function(ip, port)

    local adServer = assert(socket.udp4())
    adServer:settimeout(0)

    local enetServer = sock.newServer(ip, port)
    enetServer:setSerialization(bitser.dumps, bitser.loads)

    local gs = setmetatable({
        enetServer = enetServer,
        world = SetupWorld(),
        players = {}, -- player.id -> player{}
        players_ready = {}, -- player.id -> 1
        players_in_game = {}, -- player.id -> 1
        
        -- colliders
        playerCollider = {},
        zombieCollider = {},
        bulletCollider = {},


        zombies = {},
        zombieNum = 0,

        bullets = {},
        bulletNum = 0,

        startingZombieSpawnTime = startingZombieSpawnTime,
        maxTime = startingZombieSpawnTime,
        timer = startingZombieSpawnTime,

        updateTime=1/30,
        -- updateTime=4,

        advertiseTime=2,
        adServer = adServer,

        states = gameStates,
        currentGameState = gameStates.INIT,

    }, {__index = GameServer})

    gs:setupCallbacks()
    return gs
end

return game
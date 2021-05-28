local function reset(player)
    local player_offset_x = (math.random(1, 10) * 10)
    local player_offset_y = (math.random(1, 10) * 10)
    player.x = love.graphics.getWidth() / 2 + player_offset_x
    player.y = love.graphics.getHeight() / 2 + player_offset_y
    player.speed = 180
    player.angle = math.pi + math.random(30,90)
    player.score = 0
    player.bulletsFired = 0
    player.accuracy = 0
end

local function spawn(index, id)
    local player = {}
    reset(player)
    local name = "Player_" .. tostring(index)
    player.name = name
    player.id = id
    return player
end

local function createCollider(server, player)
    server.playerCollider[player.id] = server.world:newBSGRectangleCollider(player.x, player.y, 80, 60, 35)
    server.playerCollider[player.id]:setCollisionClass('player')
    server.playerCollider[player.id]:setObject(player)
end

local function move(server, player)
    if not server.playerCollider[player.id] then
        createCollider(server, player)
    else
        server.playerCollider[player.id]:setX(player.x)
        server.playerCollider[player.id]:setY(player.y)
        server.playerCollider[player.id]:setAngle(player.angle)
    end
    -- if playerCollider[player.id]:enter('player') then
    --     print('pps collision!')
    -- end
end

return {
    spawn = spawn,
    createCollider = createCollider,
    move = move,
    reset = reset
}
local function spawn(server)
    local zombie = {}
    server.zombieNum = server.zombieNum + 1
    zombie.id = server.zombieNum
    zombie.x = 0
    zombie.y = 0
    zombie.speed = 150
    zombie.dead = false
    local playerToTargetIndex = math.random(1, GetMapSize(server.players))

    local playerToTarget = nil
    local index = 1
    for id, player in pairs(server.players) do
        if index == playerToTargetIndex then
            playerToTarget = player
        end
        index = index + 1
    end

    zombie.playerToTarget = playerToTarget

    local side = math.random(1, 4)
    if side == 1 then
        zombie.x = -30
        zombie.y = math.random(0, love.graphics.getHeight())
    elseif side == 2 then
        zombie.x = love.graphics.getWidth()
        zombie.y = math.random(0, love.graphics.getHeight())
    elseif side == 3 then
        zombie.x = math.random(0, love.graphics.getWidth())
        zombie.y = -30
    elseif side == 4 then
        zombie.x = math.random(0, love.graphics.getWidth())
        zombie.y = love.graphics.getHeight()
    end

    table.insert(server.zombies, zombie)
    -- print('zombie spawned : ', zombie.id)
end

local function playerAngle(zombie)
    if zombie.playerToTarget then
        return math.atan2( zombie.playerToTarget.y - zombie.y, zombie.playerToTarget.x - zombie.x )
    end
end

local function move(server, zombie, collider, dt)
    collider = collider or false
    zombie.x = zombie.x + (math.cos( playerAngle(zombie) ) * zombie.speed * dt)
    zombie.y = zombie.y + (math.sin( playerAngle(zombie) ) * zombie.speed * dt)
    if collider then
        if not server.zombieCollider[zombie.id] then
        server.zombieCollider[zombie.id] = server.world:newCircleCollider(zombie.x, zombie.y, 20)
        server.zombieCollider[zombie.id]:setObject(zombie)
        server.zombieCollider[zombie.id]:setCollisionClass('zombie')
        else
            server.zombieCollider[zombie.id]:setX(zombie.x)
            server.zombieCollider[zombie.id]:setY(zombie.y)
        end
    end
    return zombie.x, zombie.y
end

local function cleanup(server)
    for i=#server.zombies,1,-1 do
        local z = server.zombies[i]
        if z.dead == true then
            table.remove(server.zombies, i)
            -- print('zd removed : ', z.id)
            if server.zombieCollider[z.id] then server.zombieCollider[z.id]:destroy() end
        end
    end
end

return {
    spawn = spawn,
    playerAngle = playerAngle,
    move = move,
    cleanup = cleanup
}
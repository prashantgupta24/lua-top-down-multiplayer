local function spawn(server, player)
    local bullet = {}
    server.bulletNum = server.bulletNum + 1
    bullet.id = server.bulletNum
    bullet.playerID = player.id
    bullet.speed = 500
    bullet.dead = false

    local bulletAngleIndex = server.angleIndex - 8
    if bulletAngleIndex < 0 then
        bulletAngleIndex = server.anglesMax - 8
    end
    bullet.direction = server.angles[bulletAngleIndex]

    bullet.x = player.x + math.cos(bullet.direction) * 40
    bullet.y = player.y + math.sin(bullet.direction) * 40
    
    if player.direction == 'left' then
        bullet.x = bullet.x - 10
    elseif  player.direction == 'right' then
        bullet.x = bullet.x + 10
    elseif player.direction == 'up' then
        bullet.y = bullet.y - 10
    elseif player.direction == 'down' then
        bullet.y = bullet.y + 10
    end
    return bullet
end

local function move(server, bullet, collider, dt)
    collider = collider or false
    bullet.x = bullet.x + (math.cos( bullet.direction ) * bullet.speed * dt)
    bullet.y = bullet.y + (math.sin( bullet.direction ) * bullet.speed * dt)
    if collider then
        if not server.bulletCollider[bullet.id] then
        server.bulletCollider[bullet.id] = server.world:newCircleCollider(bullet.x, bullet.y, 15)
        server.bulletCollider[bullet.id]:setCollisionClass('bullet')
        else
            server.bulletCollider[bullet.id]:setX(bullet.x)
            server.bulletCollider[bullet.id]:setY(bullet.y)
        end
        if server.bulletCollider[bullet.id]:enter('zombie') then
            -- print('collision bz! ' , bullet.id)
            local collision_data = server.bulletCollider[bullet.id]:getEnterCollisionData('zombie')
            local zombieHit = collision_data.collider:getObject()
            -- print('collision with : ', zombieHit.id)
            if zombieHit and not zombieHit.dead then
                local playerScore = server.players[bullet.playerID].score
                server.players[bullet.playerID].score = playerScore + 1
                zombieHit.dead = true
            end
            bullet.dead = true
        end

        if server.bulletCollider[bullet.id]:enter('player') then
            -- print('collision bp! ' , bullet.id)
            local collision_data = server.bulletCollider[bullet.id]:getEnterCollisionData('player')
            local playerHit = collision_data.collider:getObject()
            -- print('collision with : ', playerHit.id)
            if playerHit.id ~= bullet.playerID then
                bullet.dead = true
            end
        end    
    end
end

local function cleanup(server)
    for i=#server.bullets, 1, -1 do
        local b = server.bullets[i]
        if b.x < 0 or b.y < 0 or b.x > love.graphics.getWidth() or b.y > love.graphics.getHeight() then
            b.dead = true
        end
        if b.dead == true then
            table.remove(server.bullets, i)
            if server.bulletCollider[b.id] then server.bulletCollider[b.id]:destroy() end
            server.players[b.playerID].accuracy = (server.players[b.playerID].score/server.players[b.playerID].bulletsFired) * 100
        end
    end
end

return {
    spawn = spawn,
    move = move,
    cleanup = cleanup
}
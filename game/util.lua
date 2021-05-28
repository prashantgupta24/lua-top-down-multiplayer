local socket = require"socket"
local wf = require "libraries.windfield.windfield"
local player = require "player"

function GetIP()
    local s = socket.udp() 
    s:setpeername( "192.168.1.1", 80 )
    local ip, sock = s:getsockname()
    return ip
end

function CopyValues(tableFrom, tableTo)
    for key, value in pairs(tableFrom) do
        tableTo[key] = value
    end
end

function GetMapSize(map) 
	local count = 0
	for key, value in pairs(map) do
		count = count + 1
	end
	return count
end

function SetupWorld()
    local world = wf.newWorld(0, 0, false)
    world:addCollisionClass('player')
    world:addCollisionClass('bullet')
    world:addCollisionClass('zombie')
    return world
end

function DestroyWorld(world)
    --destroy ALL bodies in self.world - Thanos*2
    local bodiesInWorld = world:getBodies()
    for _, body in ipairs(bodiesInWorld) do
        body:destroy()
    end
end

-- resets values that need to be reset on game end
function ResetValuesOnEnd(server)
    server.zombies = {}
    server.zombieCollider = {}
    server.bullets = {}
    server.bulletCollider = {}
    server.playerCollider = {}
    server.bulletNum = 0
    server.zombieNum = 0
    server.maxTime = server.startingZombieSpawnTime
    server.timer = server.maxTime
end

-- resets all values on game start
function ResetGameOnStart(server)
    ResetValuesOnEnd(server)
    
    for _, playerObj in pairs(server.players) do
        player.reset(playerObj)
    end
end
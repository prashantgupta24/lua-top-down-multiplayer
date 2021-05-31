package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../?/init.lua"

local game = require "game"
local zombie = require "zombie"

function love.load()
    love.window.setTitle("Server")
    GameServer = game.newServer(GetIP(), 22122)
end

function love.update(dt)
    GameServer:update(dt)
end

function love.draw()
    -- uncomment for debug
    -- GameServer.world:draw()
    love.graphics.printf("Server address: " .. GameServer.enetServer:getAddress() .. ":" .. GameServer.enetServer:getPort(), 0, 50, love.graphics.getWidth(), "center")
    love.graphics.printf("Total number of players : " .. GetMapSize(GameServer.players), 0, 100, love.graphics.getWidth(), "center")
    love.graphics.printf("Players ready : " .. GetMapSize(GameServer.players_ready), 0, 150, love.graphics.getWidth(), "center")
    love.graphics.printf("Players in game : " .. GetMapSize(GameServer.players_in_game), 0, 200, love.graphics.getWidth(), "center")
    love.graphics.printf("Game state: " .. GameServer.currentGameState, 0, 250, love.graphics.getWidth(), "center")
end

local quit = true
function love.quit()
    if quit then
        GameServer.currentGameState = GameServer.states.SERVER_DISCONNECT
        GameServer:sendGameState()
        quit = not quit
    else
        print("Thanks for playing. Please play again soon!")
        GameServer:destroy()
        return quit
    end
    return true
end

function love.keypressed( key )
    if key == "space" then
       zombie.spawn(GameServer)
    elseif key == "escape" then
        love.event.quit()
    end
end
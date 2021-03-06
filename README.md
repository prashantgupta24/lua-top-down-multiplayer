## Multiplayer top down shooter

- Both single player and Multiplayer support. Play with your friends (on the same network)!
- Automatic local network searching for host server for multiplayer (using multicast)
- Windfield for collision detection

## Prerequisites

- http://www.love2d.org/ - Download and install Love2d.

## Demo

2 people playing on the same laptop. More people can join this game on their laptop if they are connected to the same network!

![](https://github.com/prashantgupta24/lua-top-down-multiplayer/blob/main/demo.gif)

## How to play

### 1. Build from source

#### Server

Only required if you are planning to play in Multiplayer mode.

Run `make server`

#### Game clients

Run `make client`

### 2. Use the prebuilt binaries

See `Releases`. Run `Server` on any laptop connected to the same Wifi. Run `Clients` on any laptops connected to the same Wifi. All clients will automatically find the server and play in multi-player mode.

**Note:** If a game is in session, the `Server` is not discoverable. It will automatically become discoverable once the game ends.

## Useful links

### Sockets

- https://tst2005.github.io/lua-socket/udp.html - Network support for the Lua language documentation
- https://github.com/diegonehab/luasocket
- https://love2d.org/wiki/Tutorial:Networking_with_UDP-TheServer
- https://love2d.org/wiki/Tutorial:Networking_with_UDP-TheClient
- http://www.love2d.org/forums/viewtopic.php?f=4&t=86979 - [SOLVED] Luasocket UDP broadcast
- https://en.wikipedia.org/wiki/Multicast_address
- https://code.activestate.com/recipes/578802-send-messages-between-computers/ (UDP python)
- http://w3.impa.br/~diego/software/luasocket/introduction.html

### Windfield

- https://github.com/a327ex/windfield
- https://love2d.org/wiki/Body
- https://box2d.org/documentation/md__d_1__git_hub_box2d_docs_collision.html

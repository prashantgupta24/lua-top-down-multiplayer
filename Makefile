server:
	/Applications/love.app/Contents/MacOS/love game/server
client:
	/Applications/love.app/Contents/MacOS/love game/client
build-all: build-server build-client
build-server:
	(cd game/server && zip -r server.love .)
build-client:
	(cd game/client && zip -r client.love .)
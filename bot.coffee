_      = require "lodash"
io     = require "socket.io-client"
http   = require "http"
pjson  = require "./package.json"
cookie = require "cookie"

class Bot
	constructor: (@server, @group) ->

	getSession: (callback) ->
		http.get "http://tagpro-#{@server}.koalabeast.com/", (res) =>
			if "set-cookie" of res.headers
				cookies = cookie.parse(res.headers["set-cookie"][0])

				if "tagpro" of cookies
					@session = cookies.tagpro
					console.log "Connected to #{@server}"
					callback null

				else callback "No tagpro cookie"
			else callback "No set-cookie header"
		.on "error", (e) ->
			console.error e

			callback "HTTP error"

	heartbeat: =>
		@socket.emit "touch", @position
		if @position is "page"
			@socket.emit "spectator", true

	connect: (callback) ->
		callback "Attempt to connect before getSession's callback!" unless @session?

		socket = @socket = io.connect "http://tagpro-#{@server}.koalabeast.com:81/groups/#{@group}",
			cookie: cookie.serialize("tagpro", @session)

		@position = "page"

		socket.on "connect", =>
			console.log "Connected to #{@server}//#{@group}"

			@touchInterval = setInterval @heartbeat, 10000
			@heartbeat()

			callback null

		socket.on "you", (uid) =>
			# Set name
			@botname = "Specta|#{uid[0..4]}"
			socket.emit "name", @botname

			# Send a status message
			# Delay it or it might happen before the name change
			setTimeout =>
				socket.emit "chat", "SpectaBot #{pjson.version} (by ✈) is fully operational!"
			, 200

		socket.on "play", _.once =>
			joinsocket = io.connect "http://tagpro-#{@server}.koalabeast.com:81/games/find",
				cookie: cookie.serialize("tagpro", @session)

			console.log "Finding a game"

			@location = "joining"
			@heartbeat()

			joinsocket.on "connect", =>
				console.log "Connected to #{@server}//#{@group}//games/find"

			joinsocket.on "FoundWorld", _.once (data) =>
				console.log data.url

				@location = "game"
				@heartbeat()

				joinsocket.disconnect()

				gamesocket = io.connect data.url + "?spectator=true",
					cookie: cookie.serialize("tagpro", @session)

				gamesocket.on "connect", =>
					console.log "Connected to game"

					players = {}
					importantKeys = ["name", "score"]

					nextInterval = setInterval ->
						gamesocket.emit "next"
					, 1000

					gamesocket.on "p", (updates) =>
						for update in updates
							# Add the player to the object if not already there
							if update.id not of players
								console.log "Creating player #{update.id}"
								players[update.id] = {}

							# Get a local copy of the player object
							player = players[update.id]

							# Loop the keys we want to save
							for key in importantKeys
								# If this update contains it, update the player
								if key of update
									player[key] = update[key]

					gamesocket.on "playerLeft", (id) =>
						console.log "Player left (#{id})"

						delete players[id] if id of players

					gamesocket.on "end", (data) =>
						console.log players, data.winner
						console.log "Disconnecting…"
						
						# Stop sending "next" events
						clearInterval(nextInterval)

						# Close all connections
						gamesocket.disconnect()
						socket.disconnect()

						console.log "Exiting…"
						setTimeout -> # Delay to let stuff close properly
							process.exit(0)
						, 1000

				gamesocket.on "error", =>
					process.send
						cmd: "err"
						details: "Error connecting to game (#{@server}//#{@group} - #{data.url})"
					throw new Error "Error connecting to game"

			joinsocket.on "disconnect", =>
				console.log "Disconnected from #{@server}//#{@group}//games/find"

			joinsocket.on "error", =>
				process.send
					cmd: "err"
					details: "Error joining game (#{@server}//#{@group}//games/find)"
				throw new Error "Error joining game"

		socket.on "disconnect", =>
			console.log "Disconnected from #{@server}//#{@group}"

		socket.on "error", (err) =>
			console.log err
			callback "Socket.io error on #{@server}//#{@group}"

module.exports = Bot
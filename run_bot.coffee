Bot = require "./bot"

process.on "message", (data) ->
	if data.cmd is "connect"
		bot = new Bot(data.server, data.group);
		bot.getSession (err) ->
			if err
				process.send
					cmd: "err"
					details: err
				throw new Error("Error getting session id from server \"#{bot.server}\": #{err}")

			bot.connect (err) ->
				if err
					process.send
						cmd: "err"
						details: err
					throw new Error("Error connecting to server \"#{bot.server}\": #{err}")

				process.send
					cmd: "done"

	else if data.cmd? then console.log "Received unknown command #{data.cmd}"

process.send
	cmd: "ready"
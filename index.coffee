BotController = require "./bot_controller"

for i in [0..0]
	new BotController "pi", "jostbgzu", ->
		console.log "Bot callback"
	, (err) ->
		console.log "Error: " + err

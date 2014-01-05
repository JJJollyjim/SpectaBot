child_process = require "child_process"

###
# To use:

new BotController "pi", "jostbgzu", ->
	# Callback
, (err) ->
	# Error callback

###

class BotController
	constructor: (@server, @group, callback, errorcallback, resultscallback) ->
		@child = child_process.fork "./run_bot.coffee"

		@child.on "message", (data) =>
			if data.cmd is "ready"
				@child.send
					cmd: "connect"
					server: @server
					group: @group

			else if data.cmd is "err"
				errorcallback(data.info) if errorcallback?
			else if data.cmd is "done"
				callback() if callback?
			else if data.cmd is "results"
				resultscallback(data.results) if resultscallback?

module.exports = BotController
child_process = require "child_process"

class BotController
	constructor: (@server, @group, callback, errorcallback) ->
		@child = child_process.fork("./run_bot.coffee")

		@child.on "message", (data) =>
			if data.cmd is "ready"
				@child.send
					cmd: "connect"
					server: @server
					group: @group

			else if data.cmd is "err"
				errorcallback(data.info)
			else if data.cmd is "done"
				callback() if callback?

module.exports = BotController
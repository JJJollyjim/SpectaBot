BotController = require "./bot_controller"
nodemailer    = require "nodemailer"
csv           = require "csv"
irc           = require "irc"
_             = require "lodash"

{PassThrough} = require "stream"

require "./polyfills"

csvheader = ["name", "score", "tags", "pops", "grabs", "drops", "hold", "captures", "prevent", "returns", "support"]

# Load config file
config = try
	require "./config.json"
catch
	console.log "Error loading config.json file."
	console.log "See README.md for info"

mailTransport = new nodemailer.createTransport "SES",
	AWSAccessKeyID: config.AWSAccessKeyId
	AWSSecretKey:   config.AWSSecretKey

defaultMailOptions = 
	from: "SpectaBot <jamie@kwiius.com>"
	to: "Jamie McClymont <jamie.mcclymont@gmail.com>"
	subject: "New MLTP results!"
	body: "See attatched file"
			
conf =
	chan: "#tagpro"
	serv: "irc.efnet.org"

client = new irc.Client conf.serv, "SpectaBot",
	channels: [conf.chan]

client.addListener "message", (from, to, message) ->
	if message.startsWith "!specta "
		args = message.split(" ")[1..]

		if args.length isnt 2
			client.say conf.chan, irc.colors.wrap("light_red", "Syntax error!")
			client.say conf.chan, irc.colors.wrap("red", "Usage: !specta Server Group-ID")
			client.say conf.chan, irc.colors.wrap("red", "   Eg. !specta centra mdrovdfx")
		else
			client.say conf.chan, "Joining group..."

			new BotController args[0], args[1], ->
				# Called when the bot joins the group
				console.log "Bot has joined group!"

				client.say conf.chan, "Joined group!"

			, (err) ->
				# Called if bot throws an error
				console.log "BOT THREW ERROR!", err

				client.say conf.chan, "Uh oh, child_process threw an error!"

			, (results) ->
				# Called when a game finishes

				ptStream = new PassThrough()

				options =
					attachments:
						fileName: "results.csv"
						streamSource: ptStream

				rows = [csvheader]

				for id, player of results
					rows.push [
						player["name"],      player["score"],      player["s-tags"],
						player["s-pops"],    player["s-grabs"],    player["s-drops"],
						player["s-hold"],    player["s-captures"], player["s-prevent"],
						player["s-returns"], player["s-support"]
					]

				csv()
				.from.array(rows)
				.to.stream(ptStream)

				mailTransport.sendMail _.merge(defaultMailOptions, options), (err, response) ->
					if err?
						console.error "Error sending email!"
						console.log err
					else
						console.log "Sent email successfully!"
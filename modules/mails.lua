

local interface = {
	construct = function(folder, interval, net, chan)
		mailfolder = folder
		update_timeout = 60 * interval
		network = net
		channel = chan

		last_checked = os.time()

		return true
	end,

	destruct = function()
	end,

	step = function()
		-- only check once every n minutes
		if last_checked + update_timeout < os.time() then
			-- TODO 1) get list of mails in folder
			-- TODO 2) find out if mail is relevant
			-- TODO 3) extract subject line from mail

			-- construct message
			networks[network].send("PRIVMSG", channel, "miau!!!")
		end
		last_checked = os.time()
	end,

	handlers = {
--	privmsg = function(network, sender, channel, message)
--	local mail = pcre.match(message, "^!mail ([0-9]*)$"
--	if mail then
--		-- TODO
--	end
	}
}

return interface

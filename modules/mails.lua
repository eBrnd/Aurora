local lfs = require("lfs")
local pcre = require("rex_pcre")

local interface = {
	construct = function(folder, pattern, interval, net, chan)
		mailfolder = folder
		update_timeout = 60 * interval
		network = net
		channel = chan
		matchpattern = pattern

		last_checked = os.time()

		return true
	end,

	destruct = function()
	end,

	step = function()
		-- only check once every n minutes
		if last_checked + update_timeout < os.time() then
			last_checked = os.time()
			assert(lfs.chdir(mailfolder))
			-- look at all the files in the directory
			for filename in lfs.dir(".") do
				local file = io.open(filename, "r")
				local line = file:read()
				while line do
					local subject = pcre.match(line, "Subject: (.*" .. matchpattern .. ".*)")
					if subject then
						networks[network].send("PRIVMSG", channel, "Mail: " .. subject)
						line = nil
					else
						line = file:read()
					end
				end
			end
		end
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

local lfs = require("lfs")
local pcre = require("rex_pcre")
local os = require("os")

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
			-- check email
			-- TODO

			assert(lfs.chdir(mailfolder))
			-- look at all the files in the directory
			for filename in lfs.dir(".") do
				local file = io.open(filename, "r")
				local line = file:read()
				while line do
					-- look for matching subject line
					local subject = pcre.match(line, "Subject: (.*)")
					if subject then -- "Subject: " line found
							if pcre.find(subject, matchpattern) then
								-- post to channel
								networks[network].send("PRIVMSG", channel, "Mail~ " .. subject .. pcre.find(subject, matchpattern))
						  end
						-- delete the file, so it gets deleted from the server
						file:close()
						os.remove(filename)
						line = nil
					else
						-- if no matchin subject line is found, read on
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

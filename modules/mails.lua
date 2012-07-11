local lfs = require("lfs")
local pcre = require("rex_pcre")
local os = require("os")

local interface = {
	construct = function(folder, pattern, interval, net, chan, from_addr, to_addr)
		mailfolder = folder
		update_timeout = 60 * interval
		netw = net
		chann = chan
		matchpattern = pattern
		from = from_addr
		to = to_addr

		last_checked = os.time()

		-- log for the last n messages (save them so we can mail them out on demand)
		messages = {}

		return true
	end,

	destruct = function()
	end,

	step = function()
		-- only check once every n minutes
		if last_checked + update_timeout < os.time() then
			last_checked = os.time()
			-- check email
			os.execute("offlineimap")

			assert(lfs.chdir(mailfolder))
			-- look at all the files in the directory
			for filename in lfs.dir(".") do
				local file = io.open(filename, "r")
				local line = file:read()
				local sender = nil -- declare here so it's persistent for each mail
				while line do
					-- look for sender and subject line
					if not sender then -- stop looking for it once it matches
						sender = pcre.match(line, "From: (.*) <.*>")
					end
					-- look for matching subject line
					local subject = pcre.match(line, "Subject: (.*)")
					if subject then -- "Subject: " line found
							if pcre.find(subject, matchpattern) then
								-- post to channel
								if sender then
									line_to_send = "Mail~ " .. subject .. " (from " .. sender .. ")"
								else
									line_to_send = "Mail~ " .. subject
								end
								networks[netw].send("PRIVMSG", chann, line_to_send)
							end
						-- delete the file, so it gets deleted from the server
						file:close()
						os.remove(filename)
						line = nil
					else
						-- if no matching subject line is found, read on
						line = file:read()
					end
				end
			end
		end
	end,

	handlers = {
		privmsg = function(network, sender, channel, message)
			if network == networks[netw] and channel == chann then
				local msg = {t = os.time(), s = sender, m = message}
				table.insert(messages, msg)

				-- limit size of message buffer to 1000 lines
				if table.getn(messages) > 1000 then
					table.remove(messages, 1)
				end

				local mail = pcre.match(message, "^!mail ([0-9]*)$")
				if mail then
					minutes = tonumber(mail)
					networks[netw].send("PRIVMSG", chann, "okay, mailing out the chatlog of the last " .. minutes .. " minutes.")
					min_timestamp = os.time() - minutes * 60
					mail_str = ""
						for _,msg in pairs(messages) do
							if msg.t >= min_timestamp then
								mail_str = mail_str .. "[" .. os.date("%H:%M", msg.t) .. "] " .. msg.s.nick .. ": " .. msg.m .. "\n"
							end
						end
					local tempfilename = "mail_tmp"
					local tempfile = assert(io.open(tempfilename, "w"))
					assert(tempfile:write("Hello!\n\nThis is " .. network.nick() .. ", the bot from " .. chann .. ". " .. sender.nick .. " has requested me to send the chatlog of the last " .. minutes .. " minutes to the mailing list. Here it is:\n\n"))
					assert(tempfile:write(mail_str))
					tempfile:close()
	
					os.execute("mail -s IRC-Log -r " .. from .. " " .. to .. " < " .. tempfilename)
				  os.remove(tempfilename)
				end
	
				local help = pcre.match(message, "^!help mail(s?)")
				if help then
					networks[netw].send("PRIVMSG", chann, "Mail module: \"mail n\" sends out the chatlog of the last n minutes to " .. to .. ".")
				end
			end
		end
	}
}

return interface

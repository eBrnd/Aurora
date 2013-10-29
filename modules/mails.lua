local lfs = require("lfs")
local pcre = require("rex_pcre")
local os = require("os")

local interface = { hadlers = {} }

local mails = { -- module variables
  mailfolder = nil,
  update_timeout = nil,
  netw = nil,
  chann = nil,
  matchpattern = nil,
  from = nil,
  to = nil,
  last_checked = nil,

  -- log for the last n messages (save them so we can mail them out on demand)
  messages = nil
}

function interface.construct(folder, pattern, interval, net, chan, from_addr, to_addr)
	mails.mailfolder = folder
	mails.update_timeout = 60 * interval
	mails.netw = net
	mails.chann = chan
	mails.matchpattern = pattern
	mails.from = from_addr
	mails.to = to_addr

	mails.last_checked = os.time()

	mails.messages = {}

	return true
end,

function interface.destruct()
end,

function interface.step()
	-- only check once every n minutes
	if mails.last_checked + mails.update_timeout < os.time() then
		mails.last_checked = os.time()
		-- check email
		os.execute("offlineimap")

		assert(lfs.chdir(mails.mailfolder))
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
						if pcre.find(subject, mails.matchpattern) then
							-- post to channel
							if sender then
								line_to_send = "Mail~ " .. subject .. " (from " .. sender .. ")"
							else
								line_to_send = "Mail~ " .. subject
							end
							networks[mails.netw].send("PRIVMSG", mails.chann, line_to_send)
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

function interface.handlers.privmsg(network, sender, channel, message)
	if network == networks[mails.netw] and channel == mails.chann then
		local msg = {t = os.time(), s = sender, m = message}
		table.insert(mails.messages, msg)

		-- limit size of message buffer to 1000 lines
		if table.getn(mails.messages) > 1000 then
			table.remove(mails.messages, 1)
		end

		local mail = pcre.match(message, "^!mail ([0-9]*)$")
		if mail then
			minutes = tonumber(mail)
			networks[mails.netw].send("PRIVMSG", mails.chann, "okay, mailing out the chatlog of the last " .. minutes .. " minutes.")
			min_timestamp = os.time() - minutes * 60
			mail_str = ""
				for _,msg in pairs(mails.messages) do
					if msg.t >= min_timestamp then
						mail_str = mail_str .. "[" .. os.date("%H:%M", msg.t) .. "] " .. msg.s.nick .. ": " .. msg.m .. "\n"
					end
				end
			local tempfilename = "mail_tmp"
			local tempfile = assert(io.open(tempfilename, "w"))
			assert(tempfile:write("Hello!\n\nThis is " .. network.nick() .. ", the bot from " .. mails.chann .. ". " .. sender.nick .. " has requested me to send the chatlog of the last " .. minutes .. " minutes to the mailing list. Here it is:\n\n"))
			assert(tempfile:write(mail_str))
			tempfile:close()

			os.execute("mail -s IRC-Log -r " .. mails.from .. " " .. to .. " < " .. tempfilename)
		  os.remove(tempfilename)
		end

		local help = pcre.match(message, "^!help mail(s?)")
		if help then
			networks[mails.netw].send("PRIVMSG", mails.chann, "Mail module: \"mail n\" sends out the chatlog of the last n minutes to " .. mails.to .. ".")
		end
	end
end

return interface

local os = require("os")
local http  = require("socket.http")
local pcre = require("rex_pcre")

local interface = {
  construct = function(interval, net, chan, statusurl)
    update_timeout = 60 * interval
    netw = net
    chann = chan
    url = statusurl

    last_checked = 0
    last_raumstatus = ""

		current_topic = ""

    return true
  end,

  destruct = function()
  end,

  step = function()
		-- only check once every n minutes
		if last_checked + update_timeout < os.time() then
			last_checked = os.time()

			if current_topic == "" then -- if we don't know the topic yet, send a request...
				networks[netw].send("TOPIC", chann, "")
			else -- ...and don't do anything else
				-- check the raumstatus
				local raumstatus = http.request(url)

				if raumstatus then
					raumstatus = string.gsub(raumstatus, "\n", "")
					if log then log:debug("response:" .. raumstatus) end

						if not (current_topic == "") then
							local new_topic = pcre.gsub(current_topic,
								"(?<=[{]).*?(?=[}])", raumstatus)
							if not (current_topic == new_topic) then
								networks[netw].send("TOPIC", chann, new_topic)
								networks[netw].send("PRIVMSG", chann, "Der Raum ist nun " .. raumstatus)
							end
						end
					last_raumstatus = raumstatus
				end
			end
		end
  end,

  handlers = {
		privmsg = function(network, sender, channel, message)
			if (network == networks[netw]) and (channel == chann) then
				cmd = pcre.match(message, "!raumstatus")
				if cmd then
					networks[netw].send("PRIVMSG", chann, "Der raum ist gerade " .. last_raumstatus)
				end
			end
    end,

		topic = function(network, sender, channel, message)
			if (network == networks[netw]) and (channel == chann) then
				-- keep track of topic changes so we can update the topic
				current_topic = message
				last_checked = 0 -- immediately check topic
			end
		end,

		[332] = function(network, code, nick, channel, top) -- replies to our own topic requests
			if (network == networks[netw]) and (channel == chann) then
				current_topic = top
			end
		end
  }
}

return interface

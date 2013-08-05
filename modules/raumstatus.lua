local os = require("os")
local http  = require("socket.http")
local pcre = require("rex_pcre")

local interface = {
  construct = function(interval, net, chan, statusurl)
    raumstatus_update_timeout = 60 * interval
    raumstatus_netw = net
    raumstatus_chann = chan
    url = statusurl

    raumstatus_last_checked = 0
    last_raumstatus = ""

		current_topic = ""

    return true
  end,

  destruct = function()
  end,

  step = function()
		-- only check once every n minutes
		if raumstatus_last_checked + raumstatus_update_timeout < os.time() then
			raumstatus_last_checked = os.time()

			if current_topic == "" then -- if we don't know the topic yet, send a request...
				networks[raumstatus_netw].send("TOPIC", raumstatus_chann, "")
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
								networks[raumstatus_netw].send("TOPIC", raumstatus_chann, new_topic)
								networks[raumstatus_netw].send("PRIVMSG", raumstatus_chann, "Der Raum ist nun " .. raumstatus)
							end
						end
					last_raumstatus = raumstatus
				end
			end
		end
  end,

  handlers = {
		privmsg = function(network, sender, channel, message)
			if (network == networks[raumstatus_netw]) and (channel == raumstatus_chann) then
				cmd = pcre.match(message, "!raumstatus")
				if cmd then
					networks[raumstatus_netw].send("PRIVMSG", raumstatus_chann, "Der raum ist gerade " .. last_raumstatus)
				end
			end
    end,

		topic = function(network, sender, channel, message)
			if (network == networks[raumstatus_netw]) and (channel == raumstatus_chann) then
				-- keep track of topic changes so we can update the topic
				current_topic = message
				raumstatus_last_checked = 0 -- immediately check topic
			end
		end,

		[332] = function(network, code, nick, channel, top) -- replies to our own topic requests
			if (network == networks[raumstatus_netw]) and (channel == raumstatus_chann) then
				current_topic = top
			end
		end
  }
}

return interface

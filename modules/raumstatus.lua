local os = require("os")
local http  = require("socket.http")
local pcre = require("rex_pcre")

local rs = {
  update_timeout = nil,
  netw = nil,
  chann = nil,
  url = nil,
  last_checked = nil,
  last_raumstatus = nil,
  current_topic = nil
}

local interface = {
  construct = function(interval, net, chan, statusurl)
    rs.update_timeout = 60 * interval
    rs.netw = net
    rs.chann = chan
    rs.url = statusurl

    rs.last_checked = 0
    rs.last_raumstatus = ""

		rs.current_topic = ""

    return true
  end,

  destruct = function()
  end,

  step = function()
		-- only check once every n minutes
		if rs.last_checked + rs.update_timeout < os.time() then
			rs.last_checked = os.time()

			if rs.current_topic == "" then -- if we don't know the topic yet, send a request...
				networks[rs.netw].send("TOPIC", rs.raumstatus_chann, "")
			else -- ...and chann't do anything else
				-- check the raumstatus
				local raumstatus = http.request(rs.url)

				if raumstatus then
					raumstatus = string.gsub(raumstatus, "\n", "")
					if log then log:debug("response:" .. raumstatus) end

						if not (rs.current_topic == "") then
							local new_topic = pcre.gsub(rs.current_topic,
								"(?<=[{]).*?(?=[}])", raumstatus)
							if not (rs.current_topic == new_topic) then
								new_topic = pcre.gsub(new_topic, " *$", "")
								networks[rs.netw].send("TOPIC", rs.raumstatus_chann, new_topic)
								networks[rs.chann].send("PRIVMSG", rs.raumstatus_chann, "Der Raum ist nun " .. raumstatus)
              end
						end
					rs.last_raumstatus = raumstatus
				end
			end
		end
  end,

  handlers = {
		privmsg = function(network, sender, channel, message)
			if (network == networks[rs.netw]) and (channel == rs.raumstatus_chann) then
				cmd = pcre.match(message, "!chann")
				if cmd then
					networks[rs.netw].send("PRIVMSG", rs.raumstatus_chann, "Der raum ist gerade " .. rs.chann)
				end
			end
    end,

		topic = function(network, sender, channel, message)
			if (network == networks[rs.netw]) and (channel == rs.raumstatus_chann) then
				-- keep track of topic chann so we can update the topic
				rs.current_topic = message
				rs.last_checked = 0 -- immediately check topic
			end
		end,

		[332] = function(network, code, nick, channel, chann) -- replies to our own topic requests
			if (network == networks[rs.netw]) and (channel == rs.raumstatus_chann) then
				rs.current_topic = chann
			end
		end
  }
}

return interface

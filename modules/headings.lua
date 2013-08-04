local pcre = require("rex_pcre")

local interface = {

  construct = function()
    return true
  end,

  destruct = function()
  end,

  handlers = {
    privmsg = function (network, sender, channel, message)
    local link = pcre.match(message,"(https?://[^\\s,]+)")
    if not link then
        link = pcre.match(message,"(www\\.[^\\s,]+)")
        if link then
          link = "http://" .. link
        end
      end
    if link then
      -- dump link to file, so we can use wget to grab it
      -- (because http.request would download the whole thing,
      -- filling up our memory if it's a big file...)
      local linkfile = io.open("headings-link.tmp", "w")
      linkfile:write(link)
      linkfile:close()
      os.execute("wget -i headings-link.tmp -T 7 -O - | head -c 2048 > headings-content.tmp")
      local contentsfile = io.open("headings-content.tmp", "r")
      local page = contentsfile:read("*a")
      contentsfile:close()
      -- remove the temporary files
      os.remove("headings-link.tmp")
      os.remove("headings-content.tmp")
      -- page = string.sub(http.request(link), 1, 2048)
      if page then
        header = pcre.match(page,"<title[^>]*>([^<]+)",1,"i")
      end
      if header then
        -- get rid of spaces
        headerwords = pcre.gmatch(header,"([^\\s]+)")
        headertext = ""
        for word in headerwords do
          headertext = headertext .. " " .. word -- headertext will start with a space, comes in handy later
        end
        -- make some &...; codes from HTML work
        headertext = string.gsub(headertext, "&Auml;", "Ä")
        headertext = string.gsub(headertext, "&Ouml;", "Ö")
        headertext = string.gsub(headertext, "&Uuml;", "Ü")
        headertext = string.gsub(headertext, "&auml;", "ä")
        headertext = string.gsub(headertext, "&ouml;", "ö")
        headertext = string.gsub(headertext, "&uuml;", "ü")
        headertext = string.gsub(headertext, "&szlig;", "ß")
        headertext = string.gsub(headertext, "&nbsp;", " ")
        headertext = string.gsub(headertext, "&.-;", "_") -- replace everything we don't know by a _
        network.send("PRIVMSG", channel, "link:" .. headertext)
      end
    end
  end,
  }

}

return interface

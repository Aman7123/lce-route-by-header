local url = require "socket.url"
local parsed_urls_cache = {}
local _M = {}

-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details:
-- scheme, host, port, path, query, userinfo
function _M.parse_url(host_url)
  local parsed_url = parsed_urls_cache[host_url]

  if parsed_url then return parsed_url end

  parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80
    elseif parsed_url.scheme == "https" then
      parsed_url.port = 443
    end
  end
  if not parsed_url.path then parsed_url.path = "" end

  parsed_urls_cache[host_url] = parsed_url

  return parsed_url
end

function _M.arrayToString(array)
  local str = "["
  for i, v in ipairs(array) do
    str = str .. v
    if i < #array then str = str .. "," end
  end
  return str .. "]"
end

return _M

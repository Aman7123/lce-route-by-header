local CONTENT_TYPE = "Content-Type"
local cjson = require "cjson.safe"
local url = require "socket.url"
local lce_lookup = require "kong.plugins.lce-route-by-header.lce-lookup"
local Multipart = require "multipart"
local utils = require "kong.tools.utils"
local kong = kong
local ngx = ngx
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

-- Takes an array of strings and writes them as a CSV wrapped with '[' and ']'
function _M.tbl_to_string(array)
  local str = "["
  for i, v in ipairs(array) do
    str = str .. v
    if i < #array then str = str .. "," end
  end
  return str .. "]"
end

-- Custom implementation for integrating the Kong Cache 
-- Main cache function
-- Either does a lookup in memory cache or runs the lce-lookup function
-- More information available here: https://docs.konghq.com/gateway/2.8.x/plugin-development/entities-cache/
function _M.cache(config, key)
  local value, err = kong.cache:get(key, { ttl = config.cache_ttl }, lce_lookup, config, key)
  return value, err
end

-- available in oauth2 Kong plugin
function _M.retrieve_parameters(skip_large_bodies)
  -- ngx.req.read_body()
  local body_in = _M.read_request_body(skip_large_bodies)
  local body_parameters, err
  local content_type = ngx.req.get_headers()[CONTENT_TYPE]
  if content_type and string.find(content_type:lower(), "multipart/form-data", nil, true) then
    body_parameters = Multipart(body_in, content_type):get_all()
  elseif content_type and string.find(content_type:lower(), "application/json", nil, true) then
    body_parameters, err = cjson.decode(body_in)
    if err then
      body_parameters = {}
    end
  else
    body_parameters = ngx.req.get_post_args()
  end

  return utils.table_merge(ngx.req.get_uri_args(), body_parameters)
end

-- This function can loop a Lua table recursivly for a given key.
function _M.loop_table(t, key)
  local keyLc = key:lower()
  for k, v in pairs(t) do
    if tostring(k):lower() == keyLc then
      return v
    elseif type(v) == "table" then
      local result = _M.loop_table(v, keyLc)
      if result then
        return result
      end
    end
  end
end

-- This function is a Kong custom helper to grab a request body
-- Skip large bodies is mentioned:
-- https://docs.konghq.com/gateway/2.8.x/reference/configuration/#nginx_http_client_body_buffer_size
function _M.read_request_body(skip_large_bodies)
  ngx.req.read_body()
  local body = ngx.req.get_body_data()

  if not body then
    -- see if body was buffered to tmp file, payload could have exceeded client_body_buffer_size
    local body_filepath = ngx.req.get_body_file()
    if body_filepath then
      if skip_large_bodies then
        ngx.log(ngx.ERR, "request body was buffered to disk, too large")
      else
        local file = io.open(body_filepath, "rb")
        body = file:read("*all")
        file:close()
      end
    end
  end

  return body
end

-- This function combines paths
-- This function knows to remove trailing slashes before combination
-- In the output b is appended to a
function _M.combine_paths(path_a, path_b)
  path_a = path_a or ""
  path_b = path_b or ""
  if path_a == "" or path_a == "/" then
    return path_b
  end
  if path_b == "" or path_b == "/" then
    return path_a
  end
  -- remove trailing slash from a if it exists
  if path_a:sub(-1) == "/" then
    path_a = path_a:sub(1, -2)
  end
  -- remove leading slash from b if it exists
  if path_b:sub(1, 1) == "/" then
    path_b = path_b:sub(2)
  end
  -- remove trailing slash from b if it exists
  if path_b:sub(-1) == "/" then
    path_b = path_b:sub(1, -2)
  end
  return path_a .. "/" .. path_b
end

-- This is a combiner for query strings
-- Kong will never return with an "&" at the beginning or end
-- In the output b is appended to a
function _M.combine_query_strings(query_a, query_b)
  query_a = query_a or ""
  query_b = query_b or ""
  if query_a == "" then
    return query_b
  end
  if query_b == "" then
    return query_a
  end
  return query_a .. "&" .. query_b
end

function _M.jitter_ttl(ttl, max_hours_of_jitter)
  -- Calculate jitter subtraction or addition
  local operation = math.random(0, 1)
  -- Calculate individule cache jitter
  local jitter = math.random(0, max_hours_of_jitter)
  local hourInSeconds = 3600
  if operation == 0 then
    return ttl - (jitter * hourInSeconds)
  else
    return ttl + (jitter * hourInSeconds)
  end
end

return _M


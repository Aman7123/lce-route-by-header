local cjson = require "cjson.safe"
local http = require "resty.http"
local jp_value = require "kong.plugins.lce-route-by-header.jsonpath".value
local ngx = ngx

return function(config, value)
  -- 
  -- Getters/Setters for this function variables
  if (type(config) ~= "table") and (type(value) ~= "string") then
    local a = "Invalid arguments, "
    local b = "arg#1 is ".. type(config) .. " and must be table "
    local c = "arg#2 is ".. type(value) .. " and must be string"
    return nil, (a .. b .. c)
  end
  local debug = config.debug
  -- Debug log our input items
  if debug then
    ngx.log(ngx.INFO, "Incoming value: "..value)
  end

  -- 
  -- Lookup location id in registry API
  --- Frst here are Getters/Setters
  local params = {
    method     = "GET",
    ssl_verify = false,
  }
  local httpc = http.new()
  -- Utilize the value_matching_pattern from our schema
  local url = config.registry_api_url
  if (type(config.value_matching_pattern) == "string") then
    url = config.registry_api_url:gsub(config.value_matching_pattern, value, nil, true)
  end
  -- If debug log our url in the console
  if debug then
    ngx.log(ngx.INFO, "Formatted fetch url: "..url)
  end
  -- Perform the request
  local res, err = httpc:request_uri(url, params) -- Actually GETS url
  -- Capture errors from the request
  if not res then
    return nil, err
  end
  -- Validate response status code
  if res.status ~= 200 then
    return nil, "Registry lookup returned code \'"..res.status.."\' with body \'"..res.body.."\'"
  end
  -- Decode response into table
  local apiResponse = cjson.decode(res.body)
  -- Parse and decode response body
  if (type(apiResponse) ~= "table") then
    return nil, "Response from API was \'"..res.body.."\' which could not parse to JSON"
  end
  if debug then
    ngx.log(ngx.INFO, "Found resonse body: "..res.body)
  end

  -- 
  -- Process jp lookup on response body
  -- This proces utilizes path_to_url from our schema
  --- Perform jp search
  local serviceUrl = jp_value(apiResponse, config.path_to_url)
  if debug then
    ngx.log(ngx.INFO, "Found with jp: "..cjson.encode(serviceUrl))
  end
  -- Validate serviceUrl
  if type(serviceUrl) ~= "string" then
    return nil, "Internal jsonpath parsing returned too many results"
  end

  -- 
  -- Complete
  return serviceUrl, nil
end
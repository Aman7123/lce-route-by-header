local cjson = require "cjson.safe"
local http = require "resty.http"
local jp_value = require "kong.plugins.lce-route-by-header.jsonpath".value
local ngx = ngx

return function(config, value)
  -- Validate input args
  if (type(config) ~= "table") and (type(value) ~= "string") then
    local a = "Invalid arguments, "
    local b = "arg#1 is ".. type(config) .. " and must be table "
    local c = "arg#2 is ".. type(params) .. " and must be string"
    return nil, (a .. b .. c)
  end
  local debug = config.debug
  local keys = config.key_names
  -- Debug
  if debug then
    ngx.log(ngx.INFO, "Config: "..cjson.encode(config))
    ngx.log(ngx.INFO, "Incoming value: "..value)
  end
  -- Lookup store id in API
  local params = {
    method     = "GET",
    ssl_verify = false,
  }
  local httpc = http.new()
  httpc:set_timeout(config.upstream_timeout)
  local url = config.registry_api_url:gsub((config.value_matching_pattern or ""), value, nil, true)
  if debug then
    ngx.log(ngx.INFO, "Formatted url: "..url)
  end
  local res, err = httpc:request_uri(url, params) -- Actually GETS url
  -- Ensure response is safe
  if not res then
    return nil, err
  end
  -- Parse and decode response body
  local apiResponse = cjson.decode(res.body)
  if (type(apiResponse) ~= "table") then
    return nil, "Response from API was \'"..res.body.."\' which could not parse to JSON"
  end
  if debug then
    ngx.log(ngx.INFO, "Found resonse body: "..res.body)
  end
  -- Process jp lookup
  local template = config.path_to_url:gsub((config.value_matching_pattern or ""), value, nil, true)
  if debug then
    ngx.log(ngx.INFO, "Formatted jp: "..template)
  end
  local serviceUrl = jp_value(apiResponse, template)
  if debug then
    ngx.log(ngx.INFO, "Found with jp: "..cjson.encode(serviceUrl))
  end
  if type(serviceUrl) ~= "string" then
    return nil, "Internal jsonpath parsing returned too many results"
  end
  if debug then
    ngx.log(ngx.INFO, "Found serviceUrl: "..serviceUrl)
  end
  -- Complete
  return serviceUrl, nil
end
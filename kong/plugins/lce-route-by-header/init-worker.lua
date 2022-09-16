local cjson = require "cjson.safe"
local http = require "resty.http"
local jp_value = require "kong.plugins.lce-route-by-header.jsonpath".value
local kong = kong

return function()
  local registry_api_url, path_to_id, path_to_url, cache_ttl
  local envvar = kong.configuration.untrusted_lua_sandbox_environment

  if envvar then
    for _, v in ipairs(envvar) do
      if v:match("LCE_REGISTRY_URL=") then
        registry_api_url = v:match("LCE_REGISTRY_URL=(.*)")
      elseif v:match("PATH_TO_ID=") then
        path_to_id = v:match("PATH_TO_ID=(.*)")
      elseif v:match("PATH_TO_URL=") then
        path_to_url = v:match("PATH_TO_URL=(.*)")
      elseif v:match("LCE_CACHE_TTL=") then
        cache_ttl = v:match("LCE_CACHE_TTL=(.*)")
      end
    end
  end

  -- Debug these envvars
  kong.log.info("URL to registry: "..tostring(registry_api_url))
  kong.log.info("JSONPath to ID: "..tostring(path_to_id))
  kong.log.info("JSONPath to URL: "..tostring(path_to_url))

  -- Ensure the path to an ID was provided or this will not parse
  if registry_api_url and path_to_id and path_to_url and cache_ttl then
    kong.log.info("Doing precache lookup")

    -- 
    -- Lookup location id in registry API
    --- Frst here are Getters/Setters
    local params = {
      method     = "GET",
      ssl_verify = false,
    }
    local httpc = http.new()
    -- Perform the request
    local res, err = httpc:request_uri(registry_api_url, params)
    print(cjson.encode(res.body))
    -- Capture errors from the request
    if not res then
      return nil, err
    end

    -- 
    -- Process each item in the response array
    local apiResponse = cjson.decode(res.body)
    for _, item in ipairs(apiResponse) do
      -- Parse values out of object on array
      local locationId, err1 = jp_value(item, path_to_id)
      local serviceUrl, err2 = jp_value(item, path_to_url)
      -- Check for errors
      if err1 or err2 then
        kong.log.err("Error parsing registry response: "..err1 or err2)
      end
      -- Rewrite key to string
      locationId = tostring(locationId)
      -- Enter into cache
      local _, err = 
        kong.cache:get(locationId, { ttl = tonumber(cache_ttl) }, 
          function(a)
            print("setting: "..a) 
            return a 
          end, serviceUrl)
      if err then
        return nil, err
      end
    end
  else
    kong.log.info("Not all values provided to perform precache, needed LCE_REGISTRY_URL, PATH_TO_ID, PATH_TO_URL, LCE_CACHE_TTL")
  end
end
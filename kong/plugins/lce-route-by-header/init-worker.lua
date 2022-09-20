local cjson = require "cjson.safe"
local http = require "resty.http"
local jp_value = require "kong.plugins.lce-route-by-header.jsonpath".value
local jitter_ttl = require "kong.plugins.lce-route-by-header.helpers".jitter_ttl
local kong = kong

--  ENVAR
local LCE_REGISTRY_URL = os.getenv("LCE_REGISTRY_URL")
local LCE_TO_IP = os.getenv("LCE_PATH_TO_ID")
local LCE_TO_URL = os.getenv("LCE_PATH_TO_URL")
local LCE_CACHE = os.getenv("LCE_CACHE_TTL")
local LCE_HRS_OF_JITTER = os.getenv("LCE_JITTER")
local LCE_DEBUG = os.getenv("LCE_DEBUG")

return function()
  -- 
  -- Initial variable setup and parsing from env
  local node_role = kong.configuration.role
  local registry_api_url = LCE_REGISTRY_URL
  local path_to_id = LCE_TO_IP
  local path_to_url = LCE_TO_URL
  local cache_ttl = LCE_CACHE
  local hours_of_jitter = tonumber(LCE_HRS_OF_JITTER) or 12
  local debug = tonumber(LCE_DEBUG) or 0

  -- Debug these envvars
  if debug == 1 then
    kong.log.info("URL to registry: "..tostring(registry_api_url))
    kong.log.info("JSONPath to ID: "..tostring(path_to_id))
    kong.log.info("JSONPath to URL: "..tostring(path_to_url))
  end

  -- Ensure the path to an ID was provided or this will not parse
  local isOnProperNode = (node_role == "data_plane" or node_role == "traditional")
  if registry_api_url and path_to_id and path_to_url and cache_ttl and isOnProperNode then
    kong.log.info("LCE doing precache lookup")

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
    -- Capture errors from the request
    if not res then
      kong.log.err("LCE error when making registry api lookup: "..err)
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
        kong.log.err("LCE error parsing registry response: "..(err1 or err2))
      end
      -- Rewrite key to string
      locationId = tostring(locationId)
      -- Invalidate existing cache entry
      kong.cache:invalidate(locationId)
      -- Calculate unique record ttl with jitter
      local newTtl = jitter_ttl(cache_ttl, hours_of_jitter)
      -- Enter into cache
      local _, err = 
        kong.cache:get(locationId, { ttl = newTtl }, 
          function(a, debug)
            -- Inner callback function debug
            if debug == 1 then
              kong.log.info("LCE precache "..a.." completed")
            end
            -- Return
            return a 
          end, serviceUrl, debug)
      if err then
        kong.log.err("LCE error while saving entry in cache: "..err)
      end
      if debug == 1 then
        kong.log.info("LCE precache entry: "..locationId.." = "..serviceUrl)
      end
    end
  else
    if isOnProperNode then
      kong.log.info("LCE not running precache on control plane")
    else
      kong.log.info("LCE not all values provided to perform precache, needed LCE_REGISTRY_URL, PATH_TO_ID, PATH_TO_URL, LCE_CACHE_TTL")
    end
  end
end
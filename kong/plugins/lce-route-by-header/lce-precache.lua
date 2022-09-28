local cjson = require "cjson.safe"
local http = require "resty.http"
local jp_value = require "kong.plugins.lce-route-by-header.jsonpath".value
local jitter_ttl = require "kong.plugins.lce-route-by-header.helpers".jitter_ttl
local jp_validator = require "kong.plugins.lce-route-by-header.jsonpath".parse
local kong = kong

--  ENVAR
local LCE_REGISTRY_URL = os.getenv("LCE_REGISTRY_URL")
local LCE_TO_IP = os.getenv("LCE_PATH_TO_ID")
local LCE_TO_URL = os.getenv("LCE_PATH_TO_URL")
local LCE_TO_ARRAY = os.getenv("LCE_PATH_TO_ARRAY")
local LCE_CACHE = os.getenv("LCE_CACHE_TTL")
local LCE_HRS_OF_JITTER = os.getenv("LCE_JITTER")
local LCE_DEBUG = os.getenv("LCE_DEBUG")

local function validate_jsonpath_expression(expression)
  local res, err = jp_validator(expression)
  if not res then
    kong.log.err("LCE skipping precache. The jsonpath expression ", expression, " is not valid. ", cjson.encode(err))
    return false
  end
  return true
end

return function()
  -- 
  -- Initial variable setup and parsing from env
  local node_role = kong.configuration.role
  local registry_api_url = LCE_REGISTRY_URL
  local path_to_id = LCE_TO_IP
  local path_to_url = LCE_TO_URL
  local path_to_array = LCE_TO_ARRAY or "$.*"
  local cache_ttl = LCE_CACHE
  local hours_of_jitter = tonumber(LCE_HRS_OF_JITTER) or 12
  local debug = tonumber(LCE_DEBUG) or 0

  -- Validate this function is running on the proper node
  -- If this check does not pass, the function will exit
  local isOnProperNode = (node_role == "data_plane" or node_role == "traditional")
  if not isOnProperNode then
    kong.log.err("LCE skipping precache. This plugin is only meant to run on data_plane or traditional nodes.")
    return
  end

  -- Validate ALL data is provided in the environment
  -- If this check does not pass, the function will exit
  if not (registry_api_url and path_to_id and path_to_url and cache_ttl and path_to_array) then
    kong.log.err("LCE skipping precache. The following environment variables are required: LCE_REGISTRY_URL, LCE_PATH_TO_ID, LCE_PATH_TO_ARRAY, LCE_PATH_TO_URL, LCE_CACHE_TTL")
    return
  end

  -- Validate jsonpath
  local valid_path_id = validate_jsonpath_expression(path_to_id)
  local valid_path_url = validate_jsonpath_expression(path_to_url)
  local valid_path_array = validate_jsonpath_expression(path_to_array)
  if not (valid_path_id and valid_path_url and valid_path_array) then
    kong.log.err("LCE skipping precache. The LCE_PATH_TO_ID, LCE_PATH_TO_URL, LCE_PATH_TO_ARRAY must be valid jsonpath expressions.")
    return
  end

  -- Debug these envvars
  if debug == 1 then
    kong.log.info("URL to registry: "..tostring(registry_api_url))
    kong.log.info("JSONPath to ID: "..tostring(path_to_id))
    kong.log.info("JSONPath to URL: "..tostring(path_to_url))
    kong.log.info("JSONPath to Array: "..tostring(path_to_array))
    kong.log.info("Cache TTL: "..tostring(cache_ttl))
    kong.log.info("Hours of Jitter: "..tostring(hours_of_jitter))
  end

  --  Start real logic
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
  -- Process response for proper array of objects
  local apiResponseArray = jp_value(apiResponse, path_to_array)
  -- Loop through each item in the array
  for _, item in ipairs(apiResponseArray) do
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
        function(a)
          -- Return
          return a 
        end, serviceUrl)
    if err then
      kong.log.err("LCE error while saving entry in cache: "..err)
    end
    if debug == 1 then
      kong.log.info("LCE precache entry: "..locationId.." = "..serviceUrl.." with a ttl of "..newTtl)
    end
  end
end
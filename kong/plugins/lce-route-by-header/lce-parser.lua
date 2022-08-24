local cjson = require "cjson.safe"
local arrayToString = require "kong.plugins.lce-route-by-header.helpers".arrayToString
local ngx = ngx

return function(config, params, headers)
  -- Validate input args
  if (type(keys) ~= "table") and (type(params) ~= "table") and (type(headers) ~= "table") then
    local a = "Invalid arguments, "
    local b = "arg#1 is ".. type(keys) .. " "
    local c = "arg#2 is ".. type(params) .. " "
    local d = "arg#3 is ".. type(headers) .. " "
    local e = "but all should be a table"
    return nil, (a .. b .. c .. d .. e)
  end
  local debug = config.debug
  local keys = config.key_names
  -- Debug
  if debug then
    ngx.log(ngx.INFO, "Keys: "..cjson.encode(keys))
  end

  -- Loop keys array
  for _, key in ipairs(keys) do
    -- Loop through headers object of k/v pairs and search for keys matching
    local hVal = headers[key:lower()]
    if hVal then
      if debug then
        ngx.log(ngx.INFO, "Found key value: "..hVal)
      end
      return hVal
    end
    -- Loop through params object of k/v pairs and search for keys matching
    for pKey, pVal in pairs(params) do
      -- If the key matches then return the value
      if pKey:lower() == key:lower() then
        if debug then
          ngx.log(ngx.INFO, "Found key value: "..pVal)
        end
        return pVal
      end
    end
  end
  
  -- This function should have already returned values
  return nil, "None of these keys "..arrayToString(keys).." were found in the request"
end
local cjson = require "cjson.safe"
local tbl_to_string = require "kong.plugins.lce-route-by-header.helpers".tbl_to_string
local loop = require "kong.plugins.lce-route-by-header.helpers".loop_table
local ngx = ngx

return function(config, params, headers)
  -- Validate input args
  if (type(config) ~= "table") and (type(params) ~= "table") and (type(headers) ~= "table") then
    local a = "Invalid arguments, "
    local b = "arg#1 is ".. type(config) .. " "
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
    ngx.log(ngx.INFO, "Params: "..cjson.encode(params))
    ngx.log(ngx.INFO, "Headers: "..cjson.encode(headers))
  end

  -- Loop keys array
  for _, key in ipairs(keys) do
    -- Loop through headers object of k/v pairs and search for keys matching
    local hVal = loop(headers, key)
    if hVal then
      if debug then
        ngx.log(ngx.INFO, "Found key value: "..hVal)
      end
      return hVal
    end
    -- Loop through params which is the body and/or query params
    local bVal = loop(params, key)
    if bVal then
      if debug then
        ngx.log(ngx.INFO, "Found key value: "..bVal)
      end
      return bVal
    end
  end
  
  -- This function should have already returned values
  return nil, "None of these keys "..tbl_to_string(keys).." were found in the request"
end
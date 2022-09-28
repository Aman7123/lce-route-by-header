local cjson = require "cjson.safe"
local tbl_to_string = require "kong.plugins.lce-route-by-header.helpers".tbl_to_string
local loop = require "kong.plugins.lce-route-by-header.helpers".loop_table
local jp_value = require "kong.plugins.lce-route-by-header.jsonpath".value
local ngx = ngx

return function(config, params, headers)
  -- 
  -- Getters/Setters for this function variables
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
  -- Debug log our input items
  if debug then
    ngx.log(ngx.INFO, "Keys: "..cjson.encode(keys))
    ngx.log(ngx.INFO, "Params: "..cjson.encode(params))
    ngx.log(ngx.INFO, "Headers: "..cjson.encode(headers))
  end

  -- 
  -- Loop keys array
  for _, key in ipairs(keys) do
    -- if they key contains a dollarsign ($) then it is a JSONPath
    if key:find("$") then
      local val = jp_value(params, key)
      if val then
        return val
      end
    end
    -- Loop through headers object of k/v pairs and search for keys matching
    local hVal = loop(headers, key)
    if hVal then
      if debug then
        ngx.log(ngx.INFO, "Found key value in header: "..hVal)
      end
      return tostring(hVal)
    end
    -- Loop through params which is the body and/or query params
    local bVal = loop(params, key)
    if bVal then
      if debug then
        ngx.log(ngx.INFO, "Found key value in body/args: "..bVal)
      end
      return tostring(bVal)
    end
  end
  
  -- 
  -- This function should have already returned values
  return nil, "None of these keys "..tbl_to_string(keys).." were found in the request"
end
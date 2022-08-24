local cjson = require "cjson.safe"
local PLUGIN_NAME = "lce-route-by-header"
local CONTENT_TYPE = "Content-Type"
local Multipart = require "multipart"
local utils = require "kong.tools.utils"
local lce_lookup = require "kong.plugins.lce-route-by-header.lce-lookup"
local parse_url = require "kong.plugins.lce-route-by-header.helpers".parse_url
local lce_parser = require "kong.plugins.lce-route-by-header.lce-parser"
local kong   = kong
local ngx    = ngx

-- Required Kong values
local LCE_RouteByHeader = {}
LCE_RouteByHeader.PRIORITY = 751

-- available in oauth2 Kong plugin
local function retrieve_parameters()
  ngx.req.read_body()
  local body_parameters, err
  local content_type = ngx.req.get_headers()[CONTENT_TYPE]
  if content_type and string.find(content_type:lower(), "multipart/form-data", nil, true) then
    body_parameters = Multipart(ngx.req.get_body_data(), content_type):get_all()
  elseif content_type and string.find(content_type:lower(), "application/json", nil, true) then
    body_parameters, err = cjson.decode(ngx.req.get_body_data())
    if err then
      body_parameters = {}
    end
  else
    body_parameters = ngx.req.get_post_args()
  end

  return utils.table_merge(ngx.req.get_uri_args(), body_parameters)
end

-- runs in the 'access_by_lua_block'
function LCE_RouteByHeader:access(config)
  -- Get values for processing
  local debug = config.debug
  local headers = kong.request.get_headers()
  local params = retrieve_parameters()
  -- Get special lookup value from request
  local registryValue, err = lce_parser(config, params, headers)
  -- Error and debugging on this parsing
  if err then
    kong.response.exit(config.error_response_status_code, { message = "[LCE] " .. err })
  end
  if debug then
    ngx.log(ngx.INFO, "Registry value from request  "..registryValue)
  end
  ---
  -- TODO: here do cache lookup for the URL
  ---
  -- Lookup the registryValue in the registry
  local upstreamUrl, err = lce_lookup(config, registryValue)
  -- Error and debugging on this lookup
  if err then
    kong.response.exit(config.error_response_status_code, { message = "[LCE] " .. err })
  end
  if debug then
    ngx.log(ngx.INFO, "Route from registry "..upstreamUrl)
  end
  -- Parse the URL for component table
  local splitUrl = parse_url(upstreamUrl)
  -- Setup service information virtually
  local existingPath = kong.request.get_path()
  local existingQuery = kong.request.get_raw_query()
  local upstream_query = existingQuery
  if existingQuery and splitUrl.query then
    upstream_query = existingQuery .. "&" .. splitUrl.query
  elseif splitUrl.query then
    upstream_query = splitUrl.query
  end
  local upstream_path = ((existingPath or "") .. (splitUrl.path or ""))
  if debug then
    ngx.log(ngx.INFO, "Path builder for expo: "..(upstream_path))
    ngx.log(ngx.INFO, "Query builder for expo: "..(upstream_query))
  end
  -- TODO: check for forward slash on new and old path to ensure always has slash
  kong.service.request.set_path(upstream_path)
  kong.service.request.set_raw_query(upstream_query)
  kong.service.set_target(splitUrl.host, splitUrl.port)
end

-- return our plugin object
return LCE_RouteByHeader
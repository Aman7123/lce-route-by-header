local cjson = require "cjson.safe"
local PLUGIN_NAME = "lce-route-by-header"
local read_params = require "kong.plugins.lce-route-by-header.helpers".retrieve_parameters
local lce_lookup = require "kong.plugins.lce-route-by-header.lce-lookup"
local parse_url = require "kong.plugins.lce-route-by-header.helpers".parse_url
local lce_cache = require "kong.plugins.lce-route-by-header.helpers".cache
local combine_paths = require "kong.plugins.lce-route-by-header.helpers".combine_paths
local combine_querys = require "kong.plugins.lce-route-by-header.helpers".combine_query_strings
local lce_parser = require "kong.plugins.lce-route-by-header.lce-parser"
local kong   = kong
local ngx    = ngx

-- Required Kong values
local LCE_RouteByHeader = {}
LCE_RouteByHeader.PRIORITY = 751

-- runs in the 'access_by_lua_block'
function LCE_RouteByHeader:access(config)
  -- Get values for processing
  local parsingClockStart = os.clock()
  local debug = config.debug
  local headers = kong.request.get_headers()
  local params = read_params(config.skip_large_bodies)
  -- Get special lookup value from request
  local registryValue, err = lce_parser(config, params, headers)
  -- Error and debugging on this parsing
  if err then
    kong.response.exit(config.error_response_status_code, { message = "[LCE] " .. err })
  end
  if debug then
    ngx.log(ngx.INFO, "Registry value from request  "..registryValue)
    ngx.log(ngx.INFO, "Parsing took "..os.clock()-parsingClockStart.." CPU seconds")
  end
  ---
  -- TODO: here do cache lookup for the URL
  local lookupClockStart = os.clock()
  local upstreamUrl, err = lce_cache(config, registryValue)
  -- Lookup the registryValue in the registry
  -- Currently this function below is depricated as the cache should do everything
  -- local upstreamUrl, err = lce_lookup(config, registryValue)
  -- Error and debugging on this lookup
  if err then
    kong.response.exit(config.error_response_status_code, { message = "[LCE] " .. err })
  end
  if debug then
    ngx.log(ngx.INFO, "Route from registry "..upstreamUrl)
    ngx.log(ngx.INFO, "Lookup took "..os.clock()-lookupClockStart.." CPU seconds")
  end
  -- Parse the URL for component table
  local splitUrl = parse_url(upstreamUrl)
  -- Setup service information virtually
  local upstream_query = combine_querys(splitUrl.query, kong.request.get_raw_query())
  local upstream_path = combine_paths(splitUrl.path, kong.request.get_path())
  if debug then
    ngx.log(ngx.INFO, "Path ["..tostring(splitUrl.path).."] + ["..kong.request.get_path().."] = "..(upstream_path))
    ngx.log(ngx.INFO, "Query ["..tostring(splitUrl.query).."] + ["..kong.request.get_raw_query().."] = "..(upstream_query))
    ngx.log(ngx.INFO, "Host: "..(splitUrl.host))
    ngx.log(ngx.INFO, "Port: "..tostring(splitUrl.port))
  end
  -- TODO: check for forward slash on new and old path to ensure always has slash
  kong.service.request.set_path(upstream_path)
  kong.service.request.set_raw_query(upstream_query)
  kong.service.set_target(splitUrl.host, splitUrl.port)
end

-- return our plugin object
return LCE_RouteByHeader
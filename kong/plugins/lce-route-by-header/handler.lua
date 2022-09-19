local read_params = require "kong.plugins.lce-route-by-header.helpers".retrieve_parameters
local parse_url = require "kong.plugins.lce-route-by-header.helpers".parse_url
local lce_cache = require "kong.plugins.lce-route-by-header.helpers".cache
local combine_paths = require "kong.plugins.lce-route-by-header.helpers".combine_paths
local combine_querys = require "kong.plugins.lce-route-by-header.helpers".combine_query_strings
local lce_parser = require "kong.plugins.lce-route-by-header.lce-parser"
local lce_init = require "kong.plugins.lce-route-by-header.init-worker"
local kong = kong
local ngx = ngx
local ngx_timer_at = ngx.timer.at

-- Required Kong values
local LCE_RouteByHeader = {}
LCE_RouteByHeader.PRIORITY = 751
LCE_RouteByHeader.VERSION = "1.0.0"

-- runs in the 'init_worker_by_lua_block'
function LCE_RouteByHeader:init_worker()
  local success = ngx.shared.kong_locks:add("lce_precache", true, 60)
  if success then
    local _, err = ngx_timer_at(0, lce_init)
    if err then
      kong.log.err("[LCE] Error performing precache: ", err)
    end
  end
end

-- runs in the 'access_by_lua_block'
function LCE_RouteByHeader:access(config)
  -- Plugin total execution time setters
  local clockStart = os.clock()
  
  --
  -- Start of LCE Location ID Lookup
  -- Getters/Setters for processing
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

  -- 
  -- Start LCE Store Registry Lookup
  -- Getters/Setters for processing 
  local lookupClockStart = os.clock()
  -- Lookup the registryValue in the registry
  local upstreamUrl, err = lce_cache(config, registryValue)
  -- Error and debugging on this lookup
  if err then
    kong.response.exit(config.error_response_status_code, { message = "[LCE] " .. err })
  end
  if debug then
    ngx.log(ngx.INFO, "Route from registry "..upstreamUrl)
    ngx.log(ngx.INFO, "Lookup took "..os.clock()-lookupClockStart.." CPU seconds")
  end

  --
  -- Start of LCE Upstream Redirection with Kong
  -- Setters/Getters for processing
  local splitUrl = parse_url(upstreamUrl)
  local upstream_query = combine_querys(splitUrl.query, kong.request.get_raw_query())
  local upstream_path = combine_paths(splitUrl.path, kong.request.get_path())
  -- Error and debugging on this lookup
  if debug then
    ngx.log(ngx.INFO, "Path ["..tostring(splitUrl.path).."] + ["..kong.request.get_path().."] = "..(upstream_path))
    ngx.log(ngx.INFO, "Query ["..tostring(splitUrl.query).."] + ["..kong.request.get_raw_query().."] = "..(upstream_query))
    ngx.log(ngx.INFO, "Host: "..(splitUrl.host))
    ngx.log(ngx.INFO, "Port: "..tostring(splitUrl.port))
  end
  -- Build the new Kong Service
  kong.service.request.set_path(upstream_path)
  kong.service.request.set_raw_query(upstream_query)
  kong.service.set_target(splitUrl.host, splitUrl.port)
  -- Final debug log
  if debug then
    ngx.log(ngx.INFO, "Plugin execution took "..os.clock()-clockStart.." CPU seconds")
  end
end

-- return our plugin object
return LCE_RouteByHeader
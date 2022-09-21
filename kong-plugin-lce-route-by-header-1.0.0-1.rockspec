package = "kong-plugin-lce-route-by-header"
version = "1.0.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "Kong plugin to calculate upstream"
}

dependencies = {}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.lce-route-by-header.handler"] = "kong/plugins/lce-route-by-header/handler.lua",
    ["kong.plugins.lce-route-by-header.schema"] = "kong/plugins/lce-route-by-header/schema.lua",
    ["kong.plugins.lce-route-by-header.lce-lookup"] = "kong/plugins/lce-route-by-header/lce-lookup.lua",
    ["kong.plugins.lce-route-by-header.lce-parser"] = "kong/plugins/lce-route-by-header/lce-parser.lua",
    ["kong.plugins.lce-route-by-header.jsonpath"] = "kong/plugins/lce-route-by-header/jsonpath.lua",
    ["kong.plugins.lce-route-by-header.helpers"] = "kong/plugins/lce-route-by-header/helpers.lua",
    ["kong.plugins.lce-route-by-header.lce-precache"] = "kong/plugins/lce-route-by-header/lce-precache.lua",
  }
}
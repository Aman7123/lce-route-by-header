local cjson = require "cjson.safe"
local typedefs = require "kong.db.schema.typedefs"
local PLUGIN_NAME = "lce-route-by-header"
local jp_validator = require "kong.plugins.lce-route-by-header.jsonpath".parse

return {
  name = PLUGIN_NAME,
  fields = {
    { config = {
      type = "record",
      fields = {
        {cache_ttl = {type = "number", default = 300, required = true}},
        {registry_api_url = typedefs.url { required = true}},
        {value_matching_pattern = {type = "string", default = "%%s"}},
        {key_names = {type = "array", required = true, elements = {type = "string"}}},
        {path_to_url = {type = "string", required = true}},
        {error_response_status_code = {type = "number", default = 500, required = true}},
        {cache_status_header = typedefs.header_name { default = "LCE-Cache-Status" } },
        {skip_large_bodies = {type = "boolean", default = false}},
        {debug = {type = "boolean", default = true}},
      }
    } }
  },
  -- This part of the object is used by the validation when clicking the create or update button.
  entity_checks = {
    { custom_entity_check = {
        field_sources = { "config" },
        -- This function is called when the user clicks the create or update button.
        -- entity = {"config":{"registry_api_url":"string","value_matching_pattern":"string"}}
        fn = function(entity)
          -- config = {"body":"string","file":"string","source":"string"}
          local config = entity.config
          -- registry_api_url = "string" | null
          local registry_api_url = config.registry_api_url
          -- value_matching_pattern = "string" | null
          local value_matching_pattern = config.value_matching_pattern
          -- path_to_url = "string" | null
          local path_to_url = config.path_to_url
          -- Run checks
          -- Pattern matching
          if value_matching_pattern then
            if type(value_matching_pattern) == "string" then
              if (not registry_api_url:find(value_matching_pattern)) and (not path_to_url:find(value_matching_pattern)) then
                return false, "value_matching_pattern is set, the text charecters in this field are replaced in either registry_api_url or path_to_url with the value found in the request which matched a key_names. To disable pattern replacing nil out the value_matching_pattern field"
              end
            end
          end
          -- JSONPath
          if path_to_url then
            local res, err = jp_validator(path_to_url)
            if not res then
              return false, "path_to_url is set, but it is not a valid JSONPath expression. "..cjson.encode(err)
            end
          end
          return true
        end
    } }
  }
}

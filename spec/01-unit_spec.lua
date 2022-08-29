local PLUGIN_NAME = "lce-route-by-header"

-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end

describe(PLUGIN_NAME .. ": (schema)", function()
  it("minimal configuration - value pattern in url", function()
    local ok, err = validate({
      registry_api_url = "https://api.example.com/api/v1/locations/%s",
      key_names = { "x-test" },
      path_to_url = "$.url"
    })

    assert.is_nil(err)
    assert.is_truthy(ok)
  end)
  
  it("minimal configuration - value pattern in path (GET all in the API not supported)", function()
    local ok, err = validate({
      registry_api_url = "https://api.example.com/api/v1/locations",
      key_names = { "x-test" },
      path_to_url = "$.*[?(@.id==%s)].url"
    })

    assert.is_nil(ok)
    assert(type(err) == "table")
  end)
  
  it("minimal configuration - pattern must be used in path or url when supplied", function()
    local ok, err = validate({
      registry_api_url = "https://api.example.com/api/v1/locations",
      key_names = { "x-test" },
      path_to_url = "$.url"
    })

    assert.is_nil(ok)
    assert(type(err) == "table")
  end)

  it("complete configuration - value pattern in url", function()
    local ok, err = validate({
      cache_ttl = 500,
      registry_api_url = "https://api.example.com/api/v1/locations/%s",
      value_matching_pattern = "%%s",
      key_names = { "x-test" },
      path_to_url = "$.url",
      error_response_status_code = 500,
      skip_large_bodies = false,
      debug = true
    })

    assert.is_nil(err)
    assert.is_truthy(ok)
  end)
end)

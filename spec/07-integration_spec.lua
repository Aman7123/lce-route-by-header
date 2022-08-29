local helpers = require "spec.helpers"
local PLUGIN_NAME = "lce-route-by-header"
local cjson = require "cjson.safe"

for _, strategy in helpers.each_strategy({"off", "postgres"}) do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()

      local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })

      -- Inject a test route. No need to create a service, there is a default
      -- service which will echo the request.
      local route1 = bp.routes:insert({
        paths = {
          "/negative-path",
          "/positive-path",
        },
      })
      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {
          ["cache_ttl"] = 500,
          ["registry_api_url"] = "https://mockbin.org/bin/%s",
          ["value_matching_pattern"] = "%%s",
          ["key_names"] = { "x-test" },
          ["path_to_url"] = "$.url",
          ["error_response_status_code"] = 500,
          ["skip_large_bodies"] = false,
          ["debug"] = true
        }
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    describe("request", function()
      it("does not contain any information", function()
        local r = client:get("/negative-path", {})
        -- validate that the request failed, response status 500
        assert.response(r).has.status(500)
        -- Assert the body is JSON and save JSON as table
        local jsonBody = assert.response(r).has.jsonbody()
        assert(jsonBody["message"] == "[LCE] None of these keys [x-test] were found in the request")
      end)
    end)
  end)
end

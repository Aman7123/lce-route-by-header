local PLUGIN_NAME = "lce-route-by-header"
local helpers = require("kong.plugins."..PLUGIN_NAME..".helpers")

local jsonBody = {
    body = {
        id = "1",
        url = "https://example.com",
        nested_body = {
            id = "2",
            url = "https://example.com"
        }
    }
}

describe(PLUGIN_NAME .. ": (helpers)", function()
    it("find key in JSON body", function()
        local res = helpers.loop_table(jsonBody, "url")
    
        assert(res == "https://example.com")
    end)

    it("path combinations - a = '/v1/anything' b = '/'", function()
        local a = "/v1/anything"
        local b = "/"
        local res = helpers.combine_paths(a, b)
    
        assert(res == "/v1/anything")
    end)

    it("path combinations - a = '/' b = '/v1/anything'", function()
        local a = "/"
        local b = "/v1/anything"
        local res = helpers.combine_paths(a, b)
    
        assert(res == "/v1/anything")
    end)

    it("path combinations - a = '/v1/anything' b = '/upstream'", function()
        local a = "/v1/anything"
        local b = "/upstream"
        local res = helpers.combine_paths(a, b)
    
        assert(res == "/v1/anything/upstream")
    end)

    it("path combinations - a = '/v1/anything' b = '/upstream/'", function()
        local a = "/v1/anything"
        local b = "/upstream/"
        local res = helpers.combine_paths(a, b)
    
        assert(res == "/v1/anything/upstream")
    end)

    it("path combinations - a = '/v1/anything/' b = '/upstream/'", function()
        local a = "/v1/anything/"
        local b = "/upstream/"
        local res = helpers.combine_paths(a, b)
    
        assert(res == "/v1/anything/upstream")
    end)

    it("query param combinations - a = 'q_a=11&q_b=22' b = 'q_c=33'", function()
        local a = "q_a=11&q_b=22"
        local b = "q_c=33"
        local res = helpers.combine_query_strings(a, b)
    
        assert(res == "q_a=11&q_b=22&q_c=33")
    end)

end)
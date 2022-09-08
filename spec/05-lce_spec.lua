local PLUGIN_NAME = "lce-route-by-header"
local lce_lookup = require("kong.plugins."..PLUGIN_NAME..".lce-lookup")
local lce_parser = require("kong.plugins."..PLUGIN_NAME..".lce-parser")

-- LCE Parser Variables
local parserConfig = {
    key_names = {"x-lce-key"}
}
local parserHeaders = {
    ["test-header"] = "test-value",
    ["x-lce-key"] = "value"
}
local parserHeadersIsNumber = {
    ["test-header"] = "test-value",
    ["x-lce-key"] = 1010001
}
local parserBody = {
    ["id"] = "1",
    ["x-lce-key"] = "0d7ecb06-3f9b-4d85-9646-d29a7edf9b94"
}

--  LCE Lookup variables
local lookupValue = "0d7ecb06-3f9b-4d85-9646-d29a7edf9b94"
local lookupConfig = {
    ["registry_api_url"] = "https://mockbin.org/bin/%s",
    ["value_matching_pattern"] = "%%s",
    ["path_to_url"] = "$.url",
}
local notFoundAPIConfig = {
    ["registry_api_url"] = "https://mockbin.org/bin/5cab99f3-eb73-43f5-9da0-f0e0c1d0b5b8",
    ["path_to_url"] = "$.url",
}

describe(PLUGIN_NAME .. ": (LCE functions)", function()
    it("parse value - headers first", function()
        local res, err = lce_parser(parserConfig, parserBody, parserHeaders)
        assert(res == "value")
        assert.is_nil(err)
    end)
    it("parse value - header is number", function()
        local res, err = lce_parser(parserConfig, {}, parserHeadersIsNumber)
        assert(res == "1010001")
        assert(type(res) == "string")
        assert.is_nil(err)
    end)

    it("parse value - body second", function()
        local res, err = lce_parser(parserConfig, parserBody, {})
        
        assert(res == "0d7ecb06-3f9b-4d85-9646-d29a7edf9b94")
        assert.is_nil(err)
    end)
    
    it("upstream lookup from API", function()
        local res, err = lce_lookup(lookupConfig, lookupValue)
        
        assert(res == "https://proxy.aaronrenner.com/v1/anything")
        assert.is_nil(err)
    end)

    it("catch error from lookup API", function()
        local res, err = lce_lookup(notFoundAPIConfig, parserBody, {})
        
        assert(type(err) == "string")
        assert.is_nil(res)
    end)
end)
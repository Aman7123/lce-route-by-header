local lce_init = require "kong.plugins.lce-route-by-header.init-worker"

-- Kong Admin API Additions
return {
  ["/precache"] = {
    before = function(self, db, helpers)
      local res, err = lce_init()
      if err then
        kong.response.exit(500, { message = "[LCE] Error performing precache: "..err })
      end
      kong.response.exit(200, { message = "[LCE] Precache completed" })
    end,
    GET = {},
    POST = {},
    PUT = {},
    PATCH = {},
  },
}
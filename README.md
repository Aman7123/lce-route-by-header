LCE Route By Header
====================
* Experimental code in `develop` branch
* Prerequisites: Lua knowledge / experience

![network flow](resources/network-flow.png)

This custom route by header plugin is used to build a custom service for the next network hop. The next network hop is obtained from a `GET By ID` to a registry API service. The URL is a configurable location inside the JSON response form the API registry service, can be set with `path_to_url` which is explained in more detail below. The URL should be in the format `<scheme>://<host>` (ex. `https://example.com`).

Configuration
=================================
| Value | Required | Default | Description |
|---|---|---|---|
| cache_ttl | ✅ | 300 | How long to keep the store registry URL in memory |
| registry_api_url | ✅ |  | A URL to the registry API that returns upstream URLs |
| value_matching_pattern |  | %%s | A special character that can be replaced in the `registry_api_url` or `path_to_url` |
| key_names | ✅ |  | CSV of case insensitive strings that are matched to an HTTP request information in the order `headers -> query params -> body`. Body search only works if form-data or JSON |
| path_to_url | ✅ |  | A [jq](https://github.com/hy05190134/lua-jsonpath) value to a URL in the registry response that is used as the upstream |
| error_response_status_code | ✅ | 500 | The global response code used for all internal errors in the code |
| skip_large_bodies |  | false | An optional value that defines whether Kong should send large bodies that are buffered to disk. Note that enabling this option will have an impact on system memory depending on the number of requests simultaneously in flight at any given point in time and on the maximum size of each request. Also this option blocks all requests being handled by the nginx workers. That could be tens of thousands of other transactions that are not being processed. For small I/O operations, such a delay would generally not be problematic. In cases where the body size is in the order of MB, such a delay would cause notable interruptions in request processing. Given all of the potential downsides resulting from enabling this option, consider increasing the [client_body_buffer_size](https://docs.konghq.com/gateway/2.8.x/reference/configuration/#nginx_http_client_body_buffer_size) value instead |
| debug |  | true | Creates logs in the proxy that explains processing flow using the INFO [log level](https://docs.konghq.com/gateway/2.8.x/reference/configuration/#log_level) |

Config Example
=================================
```json
{
  "cache_ttl": 300,
  "registry_api_url": "https://mockbin.org/bin/%s",
  "value_matching_pattern": "%%s",
  "key_names": [
    "x-test",
    "x-mkbin",
    "x-custom-url"
  ],
  "path_to_url": "$.url",
  "error_response_status_code": 500,
  "skip_large_bodies": false,
  "debug": true
}
```

Installation
=================================
Please review [plugin distribution](https://docs.konghq.com/gateway/latest/plugin-development/distribution/)

### Compile Custom Kong Gateway
```bash
docker build . -t '<image-name>:<version>`
```

Testing
=================================
This template was designed to work with the
[`kong-pongo`](https://github.com/Kong/kong-pongo) and
[`kong-vagrant`](https://github.com/Kong/kong-vagrant) development environments.

To test please install one framework above and run `pongo run` in the default repo

Example resources
=================================
* For a complete walkthrough of Kong plugin creation check [this blogpost on the Kong website](https://konghq.com/blog/custom-lua-plugin-kong-gateway).
* For Kong PDK resources see [Kong docs](https://docs.konghq.com/gateway/latest/pdk/)
LCE Route By Header
====================
* Experimental code in `develop` branch
* Prerequisites: Lua knowledge / experience
* Kong version: 3.0.0

<img src="resources/network-flow.png" alt="network flow" width=850 height=500 />

This custom route by header plugin is used to build a custom service for the next network hop. The next network hop is obtained from a `GET By ID` to a registry API service. The URL is a configurable location inside the JSON response form the API registry service, can be set with `path_to_url` which is explained in more detail below. The URL should be in the format `<scheme>://<host>` (ex. `https://example.com`).

A new feature in this plugin is its ability to use a `GET All` endpoint for obtaining an array of registry block objects in the registry api. To take advantage of this feature you MUST have the `Environment Configuration` variable applied and configured correctly. This feature is known as "pre-cache" and is ran by default on initial Kong worker startup using the [init_worker](https://docs.konghq.com/gateway/latest/plugin-development/custom-logic/).

Environment Configuration
=================================
| ENV | Example | Description |
|---|---|---|
| LCE_REGISTRY_URL | https://mockbin.org/bin | This is the URL that leads to a GET All |
| LCE_PATH_TO_ID | $.id | The [jp](https://github.com/hy05190134/lua-jsonpath) to the locationNumber |
| LCE_PATH_TO_URL | $.url | The [jp](https://github.com/hy05190134/lua-jsonpath) to the upstream URL |
| LCE_PATH_TO_ARRAY | $.data | (default $.*) The [jp](https://github.com/hy05190134/lua-jsonpath) to array of registry objects |
| LCE_CACHE_TTL | 259200 | The time in seconds to keep the key:value pairs |
| LCE_JITTER | 12 | (default 12) The hours to jitter the TTL for each record by |
| LCE_DEBUG | 1 | 0=false / 1=true for use in init_worker precache |

Plugin Configuration
=================================
| Value | Required | Default | Description |
|---|---|---|---|
| cache_ttl | ✅ | 300 | How long in seconds to keep the store registry URL in memory |
| registry_api_url | ✅ |  | A URL to the registry API that returns upstream URLs |
| value_matching_pattern |  | %%s | A special character that can be replaced in the `registry_api_url` or `path_to_url`. The value in this field is interpreted as a [Lua pattern](https://www.lua.org/pil/20.2.html) this means sometimes the value needs to be escaped as in the default example  |
| key_names | ✅ |  | CSV of case insensitive strings that are matched to an HTTP request information in the order `headers -> query params -> body`. Body search only works if form-data or JSON |
| path_to_url | ✅ |  | A [jp](https://github.com/hy05190134/lua-jsonpath) value to a URL in the registry response that is used as the upstream |
| error_response_status_code | ✅ | 500 | The global response code used for all internal errors in the code |
| cache_status_header | | "LCE-Cache-Status" | If provided a "HIT" or "MISS" value relays if the cache was used (HIT) or if the upstream value was obtained from the registry api (MISS) |
| skip_large_bodies |  | false | An optional value that defines whether Kong should send large bodies that are buffered to disk. Note that enabling this option will have an impact on system memory depending on the number of requests simultaneously in flight at any given point in time and on the maximum size of each request. Also this option blocks all requests being handled by the nginx workers. That could be tens of thousands of other transactions that are not being processed. For small I/O operations, such a delay would generally not be problematic. In cases where the body size is in the order of MB, such a delay would cause notable interruptions in request processing. Given all of the potential downsides resulting from enabling this option, consider increasing the [client_body_buffer_size](https://docs.konghq.com/gateway/latest/reference/configuration/#nginx_http_client_body_buffer_size) value instead |
| debug |  | true | Creates logs in the proxy that explains processing flow using the INFO [log level](https://docs.konghq.com/gateway/latest/reference/configuration/#log_level) |

Plugin Config Example
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

Tips for repopulating internal cache
=================================
> "Trigger any kind of config change and that will automatically purge the cache. e.g. create a fake Consumer and just PATCH it whenever the cache needs to be dropped" - Datong Sun (Principal Engineer, Gateway Team, Kong)

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
* For a complete walkthrough of Kong plugin creation check [this blog post on the Kong website](https://konghq.com/blog/custom-lua-plugin-kong-gateway).
* For Kong PDK resources see [Kong docs](https://docs.konghq.com/gateway/latest/pdk/)
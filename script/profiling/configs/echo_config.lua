local cjson = require('cjson')

local configuration = cjson.encode(cjson.decode([[{
  "services": [
    {
      "proxy": {
        "hosts": [
          "localhost",
          "127.0.0.1"
        ],
        "policy_chain": [
          { "name": "apicast.policy.echo" }
        ]
      }
    }
  ]
}
]]))

local function data_url(mime_type, content)
  return string.format([[data:%s,%s]],mime_type, ngx.escape_uri(content))
end

return {
  worker_processes = '1',
  lua_code_cache = 'on',
  configuration = data_url('application/json', configuration),
  port = { apicast = 9000, echo = 9001, management = 9002, backend = 9003 },
  timer_resolution = false,
}


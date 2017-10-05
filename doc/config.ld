file = {
  '../apicast/src/proxy.lua',
  '../apicast/src/configuration/service.lua',
  '../apicast/src/resty/http_ng.lua',
  '../apicast/src/resty/http_ng/backend/resty.lua',
  '../apicast/src/backend_client.lua',
  '../apicast/src/resty/synchronization.lua',
}
dir = '../doc/api'
project = 'APIcast'
title = 'NGINX based API gateway used to integrate your internal and external API services with 3scale’s API Management Platform'
merge = true
format = 'markdown'

new_type("http","HTTP")
new_type("http_ng.backend","http_ng.backend")

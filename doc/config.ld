file = {
  '../gateway/src/apicast',
  '../gateway/src/resty',
}
dir = '../doc/lua'
project = 'APIcast'
title = 'NGINX based API gateway used to integrate your internal and external API services with 3scale’s API Management Platform'
merge = true
format = 'markdown'
not_luadoc = true

new_type("http","HTTP")
new_type("http_ng.backend","http_ng.backend")

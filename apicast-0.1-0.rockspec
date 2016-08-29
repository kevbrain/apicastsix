package = "apicast"
source = {
url = '.'
}
version = '0.1-0'
description = {
}
dependencies = {
  'luacheck >= 0',
  'busted  >= 0',
  'lua-cjson >= 0',
  'inspect >= 0',
  'lua-resty-http >= 0'
}
build = {
   type = "builtin",
   modules = {
   }
}

package = "apicast-test"
source = { url = '.' }
version = '0.0-0'
dependencies = {
  'luacheck >= 0',
  'busted  >= 0',
  'lua-cjson >= 0'
}
build = {
  type = "builtin",
  modules = { }
}

package = "apicast-test"
source = { url = '.' }
version = '0.0-0'
dependencies = {
  'luacheck == 0.18.0',
  'busted  >= 0',
  'ldoc >= 0',
  'lua-resty-repl >= 0',
}
build = {
  type = "builtin",
  modules = { }
}

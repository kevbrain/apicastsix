package = "apicast-test"
source = { url = '.' }
version = '0.0-0'
dependencies = {
  'busted  >= 0',
  'ldoc >= 0',
  'lua-resty-repl >= 0',
  'lua-resty-iputils == 0.3.0-1', -- just as dev dependency before gets bumped to runtime
}
build = {
  type = "builtin",
  modules = { }
}

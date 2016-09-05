package = "apicast"
source = { url = '.' }
version = '0.1-0'
dependencies = {
  'lua-resty-http >= 0',
  'inspect >= 3.0',
  'router >= 2.0'
}
build = {
   type = "builtin",
   modules = {
   }
}

use lib 't';
use TestAPIcast 'no_plan';

$ENV{APICAST_CUSTOM_CONFIG} = "$Test::Nginx::Util::HtmlDir/custom.lua";

env_to_nginx('APICAST_CUSTOM_CONFIG');

run_tests();

__DATA__

=== TEST 1: loading custom config file works
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  location /t {
    content_by_lua_block {
      path = package.path
      require('apicast.proxy')
      assert(path == package.path)
      package.loaded['apicast.proxy'] = nil
      ngx.exit(ngx.HTTP_OK)
    }
  }
--- request
GET /t
--- user_files
>>> custom.lua
return { setup = function() print('loaded custom.lua') end }
--- error_log
loaded custom.lua

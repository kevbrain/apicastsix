use lib 't';
use Test::APIcast 'no_plan';

run_tests();

__DATA__

=== TEST 1: get context reference
get context reference number
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  location = /t {
    content_by_lua_block {
      ngx.say(require('resty.ctx').ref())
    }
  }
--- request
GET /t
--- response_body
1
--- no_error_log
[error]



=== TEST 2: stash context reference
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  set $ctx_ref -1;

  location = /t {
    rewrite_by_lua_block {
      require('resty.ctx').stash()
    }

    content_by_lua_block {
      ngx.say(ngx.var.ctx_ref)
    }
  }
--- request
GET /t
--- response_body
1
--- no_error_log
[error]



=== TEST 3: apply context reference
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  set $ctx_ref -1;

  location = /t {
    rewrite_by_lua_block {
      require('resty.ctx').stash()
      ngx.ctx.foo = 'bar'
    }

    content_by_lua_block {
      ngx.exec('@redirect')
    }
  }

  location @redirect {
    internal;

    rewrite_by_lua_block {
      require('resty.ctx').apply()
      ngx.say(ngx.ctx.foo)
    }
  }
--- request
GET /t
--- response_body
bar
--- no_error_log
[error]



=== TEST 4: context is not garbage collected
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  set $ctx_ref -1;

  location = /t {
    rewrite_by_lua_block {
      require('resty.ctx').stash()
      ngx.ctx.foo = 'bar'
    }

    content_by_lua_block {
      ngx.exec('@redirect')
    }
  }

  location @redirect {
    internal;

    rewrite_by_lua_block {
      collectgarbage()
      require('resty.ctx').apply()
    }

    post_action @out_of_band;

    content_by_lua_block {
      collectgarbage()
      ngx.say(ngx.ctx.foo)
    }
  }

  location @out_of_band {
    rewrite_by_lua_block {
      collectgarbage()
      require('resty.ctx').apply()
    }

    content_by_lua_block {
      collectgarbage()
      ngx.say(ngx.ctx.foo)
    }
  }
--- request
GET /t
--- response_body
bar

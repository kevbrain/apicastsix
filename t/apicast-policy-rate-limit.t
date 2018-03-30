use lib 't';
use Test::APIcast 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: Invalid limiter name.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "invalid",
                      key = "test1",
                      conn = 20,
                      burst = 10,
                      delay = 0.5
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500
--- error_log
unknown limiter

=== TEST 2: Invalid limiter value.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "fixed_window",
                      key = "test2",
                      count = 0,
                      window = 10
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500
--- error_log
unknown limiter

=== TEST 3: Invalid redis url.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test3",
                      conn = 20,
                      burst = 10,
                      delay = 0.5
                    }
                  },
                  redis_url = "redis://invalidhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500

=== TEST 5: No redis url.
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test5",
                      rate = 20,
                      burst = 10
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 200
--- no_error_log
[error]

=== TEST 6: Success with multiple limiters.
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test6_1",
                      rate = 20,
                      burst = 10
                    },
                    {
                      name = "connections",
                      key = "test6_2",
                      conn = 20,
                      burst = 10,
                      delay = 0.5
                    },
                    {
                      name = "fixed_window",
                      key = "test6_3",
                      count = 20,
                      window = 10
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /flush_redis {
    content_by_lua_block {
      local redis = require('resty.redis'):new()
      redis:connect('127.0.0.1', 6379)
      redis:select(1)
      redis:del("test6_1", "test6_2", "test6_3")
    }
  }

--- pipelined_requests eval
["GET /flush_redis","GET /"]
--- error_code eval
[200, 200]
--- no_error_log
[error]
need to delay by

=== TEST 7: Rejected (conn).
Return 429 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test7",
                      conn = 1,
                      burst = 0,
                      delay = 2
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test7",
                      conn = 1,
                      burst = 0,
                      delay = 2
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /flush_redis {
    content_by_lua_block {
      local redis = require('resty.redis'):new()
      redis:connect('127.0.0.1', 6379)
      redis:select(1)
      redis:del("test7")
    }
  }

--- pipelined_requests eval
["GET /flush_redis","GET /"]
--- error_code eval
[200, 429]

=== TEST 8: Rejected (req).
Return 429 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test8",
                      rate = 1,
                      burst = 0
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test8",
                      rate = 1,
                      burst = 0
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /flush_redis {
    content_by_lua_block {
      local redis = require('resty.redis'):new()
      redis:connect('127.0.0.1', 6379)
      redis:select(1)
      redis:del("test8")
    }
  }

--- pipelined_requests eval
["GET /flush_redis","GET /"]
--- error_code eval
[200, 429]

=== TEST 9: Rejected (count).
Return 429 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "fixed_window",
                      key = "test9",
                      count = 1,
                      window = 10
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "fixed_window",
                      key = "test9",
                      count = 1,
                      window = 10
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /flush_redis {
    content_by_lua_block {
      local redis = require('resty.redis'):new()
      redis:connect('127.0.0.1', 6379)
      redis:select(1)
      redis:del("test9")
    }
  }

--- pipelined_requests eval
["GET /flush_redis","GET /"]
--- error_code eval
[200, 429]

=== TEST 10: Delay (conn).
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test10",
                      conn = 1,
                      burst = 1,
                      delay = 2
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test10",
                      conn = 1,
                      burst = 1,
                      delay = 2
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /flush_redis {
    content_by_lua_block {
      local redis = require('resty.redis'):new()
      redis:connect('127.0.0.1', 6379)
      redis:select(1)
      redis:del("test10")
    }
  }

--- pipelined_requests eval
["GET /flush_redis","GET /"]
--- error_code eval
[200, 200]

=== TEST 11: Delay (req).
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test11",
                      rate = 1,
                      burst = 1
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test11",
                      rate = 1,
                      burst = 1
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /flush_redis {
    content_by_lua_block {
      local redis = require('resty.redis'):new()
      redis:connect('127.0.0.1', 6379)
      redis:select(1)
      redis:del("test11")
    }
  }

--- pipelined_requests eval
["GET /flush_redis","GET /"]
--- error_code eval
[200, 200]

=== TEST 12: Rejected (conn) (no redis).
Return 429 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test12",
                      conn = 1,
                      burst = 0,
                      delay = 2
                    }
                  }
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test12",
                      conn = 1,
                      burst = 0,
                      delay = 2
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 429
--- error_log
Requests over the limit.

=== TEST 13: Rejected (req) (no redis).
Return 429 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test13",
                      rate = 1,
                      burst = 0
                    }
                  }
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test13",
                      rate = 1,
                      burst = 0
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 429
--- error_log
Requests over the limit.

=== TEST 14: Rejected (count) (no redis).
Return 429 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "fixed_window",
                      key = "test14",
                      count = 1,
                      window = 10
                    }
                  }
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "fixed_window",
                      key = "test14",
                      count = 1,
                      window = 10
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 429
--- error_log
Requests over the limit.

=== TEST 15: Delay (conn) (no redis).
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test15",
                      conn = 1,
                      burst = 1,
                      delay = 2
                    }
                  }
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "connections",
                      key = "test15",
                      conn = 1,
                      burst = 1,
                      delay = 2
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

--- request
GET /
--- error_code: 200
--- error_log
need to delay by

=== TEST 16: Delay (req) (no redis).
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limiter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test16",
                      rate = 1,
                      burst = 1
                    }
                  }
                }
              },
              {
                name = "apicast.policy.rate_limit",
                configuration = {
                  limiters = {
                    {
                      name = "leaky_bucket",
                      key = "test16",
                      rate = 1,
                      burst = 1
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict limiter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

--- request
GET /
--- error_code: 200
--- error_log
need to delay by

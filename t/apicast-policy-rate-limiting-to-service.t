use lib 't';
use Test::APIcast 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: Invalid limitter class.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.invalid",
                      key = "test1",
                      values = {20, 10, 0.5}
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
  lua_shared_dict limitter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500
--- error_log
failed to find module

=== TEST 2: Invalid limitter value.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.count",
                      key = "test2",
                      values = {0, 10}
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
  lua_shared_dict limitter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500
--- error_log
failed to instantiate limitter

=== TEST 3: Invalid redis url.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.conn",
                      key = "test3",
                      values = {20, 10, 0.5}
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
  lua_shared_dict limitter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500

=== TEST 5: No redis url.
Return 500 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.req",
                      key = "test5",
                      values = {20, 10}
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
  lua_shared_dict limitter 1m;

--- config
  include $TEST_NGINX_APICAST_CONFIG;

--- request
GET /
--- error_code: 500
--- error_log
No Redis information.

=== TEST 6: Success with multiple limiters and redis.
Return 200 code.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require "resty.core"
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.req",
                      key = "test6_1",
                      values = {20, 10}
                    },
                    {
                      limitter = "resty.limit.conn",
                      key = "test6_2",
                      values = {20, 10, 0.5}
                    },
                    {
                      limitter = "resty.limit.count",
                      key = "test6_3",
                      values = {20, 10}
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
  lua_shared_dict limitter 1m;

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
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.conn",
                      key = "test7",
                      values = {1, 0, 2}
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.conn",
                      key = "test7",
                      values = {1, 0, 2}
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
  lua_shared_dict limitter 1m;

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
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.req",
                      key = "test8",
                      values = {1, 0}
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.req",
                      key = "test8",
                      values = {1, 0}
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
  lua_shared_dict limitter 1m;

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
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.count",
                      key = "test9",
                      values = {1, 10}
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.count",
                      key = "test9",
                      values = {1, 10}
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
  lua_shared_dict limitter 1m;

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
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.conn",
                      key = "test10",
                      values = {1, 1, 2}
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.conn",
                      key = "test10",
                      values = {1, 1, 2}
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
  lua_shared_dict limitter 1m;

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
    ngx.shared.limitter:flush_all()
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          proxy = {
            policy_chain = {
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.req",
                      key = "test11",
                      values = {1, 1}
                    }
                  },
                  redis_url = "redis://localhost:6379/1"
                }
              },
              {
                name = "apicast.policy.rate_limiting_to_service",
                configuration = {
                  limitters = {
                    {
                      limitter = "resty.limit.req",
                      key = "test11",
                      values = {1, 1}
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
  lua_shared_dict limitter 1m;

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

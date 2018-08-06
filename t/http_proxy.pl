use File::Temp qw( tempfile );

my $http_proxy_pid;

$ENV{TEST_NGINX_HTTP_PROXY_PORT} = Test::APIcast->get_random_port();

$ENV{TEST_NGINX_HTTP_PROXY} = "http://$Test::Nginx::Util::ServerAddr:$ENV{TEST_NGINX_HTTP_PROXY_PORT}";
$ENV{TEST_NGINX_HTTPS_PROXY} = "http://$Test::Nginx::Util::ServerAddr:$ENV{TEST_NGINX_HTTP_PROXY_PORT}";

sub start_proxy {
    if ($http_proxy_pid = fork) {
        if ($Test::Nginx::Util::Verbose) {
            warn "started proxy process $http_proxy_pid";
        }

        sleep( Test::Nginx::Util->sleep_time() );
    } else {
        my $err_log_file = $Test::Nginx::Util::ErrLogFile;
        my ($proxy_config, $proxy_config_file) = tempfile();

        print $proxy_config Test::Nginx::Util::expand_env_in_config <<'NGINX';
daemon off;

events {
    worker_connections 1024;
}

stream {
    lua_code_cache on;
    lua_socket_log_errors off;

    resolver local=on;
    init_worker_by_lua_block { ngx.log(ngx.INFO, 'started proxy worker') }

    init_by_lua_block { proxy = require('t.fixtures.proxy') }

    # define a TCP server listening on the port 1234:
    server {
        listen $TEST_NGINX_HTTP_PROXY_PORT;
        content_by_lua_block { proxy() }
    }
}
NGINX
        close $proxy_config;
        warn($proxy_config_file);

        if ($Test::Nginx::Util::Verbose) {
            warn "starting proxy process on port $ENV{TEST_NGINX_HTTP_PROXY_PORT}";
        }

        exec("$Test::Nginx::Util::NginxBinary",
            '-p', $Test::Nginx::Util::ServRoot,
            '-c', $proxy_config_file,
            '-g', "error_log $err_log_file $Test::Nginx::Util::LogLevel;"
        );
    }
}

Test::Nginx::Socket::set_http_config_filter(sub {
    my $config = shift;

    if (defined $http_proxy_pid) {
        if ($Test::Nginx::Util::Verbose) {
            warn "reloading proxy process $http_proxy_pid";
        }

        # reload proxy to reopen log file
        kill 'HUP', $http_proxy_pid;

    } else {
        start_proxy();
    }

    return $config;
});

add_cleanup_handler(sub {
    if (defined $http_proxy_pid && !$ENV{TEST_NGINX_NO_CLEAN}) {
        if ($Test::Nginx::Util::Verbose) {
            warn "stopping proxy process $http_proxy_pid";
        }

        Test::Nginx::Util::kill_process($http_proxy_pid, 1, 'proxy');
        undef $http_proxy_pid;
    }
});

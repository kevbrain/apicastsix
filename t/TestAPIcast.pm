package TestAPIcast;
use strict;
use warnings FATAL => 'all';
use v5.10.1;

BEGIN {
    $ENV{TEST_NGINX_BINARY} ||= 'openresty';
}

use Test::Nginx::Socket::Lua -Base;

use Cwd qw(cwd);

my $pwd = cwd();
our $path = $ENV{TEST_NGINX_APICAST_PATH} ||= "$pwd/apicast";
our $spec = "$pwd/spec";
our $servroot = $Test::Nginx::Util::ServRoot;

$ENV{TEST_NGINX_LUA_PATH} = "$path/src/?.lua;;";
$ENV{TEST_NGINX_MANAGEMENT_CONFIG} = "$path/conf.d/management.conf";
$ENV{TEST_NGINX_UPSTREAM_CONFIG} = "$path/http.d/upstream.conf";
$ENV{TEST_NGINX_BACKEND_CONFIG} = "$path/conf.d/backend.conf";
$ENV{TEST_NGINX_APICAST_CONFIG} = "$path/conf.d/apicast.conf";

if ($ENV{DEBUG}) {
    $ENV{TEST_NGINX_ERROR_LOG} ||= '/dev/stderr';
}

env_to_nginx("TEST_NGINX_SERVER_PORT=$Test::Nginx::Util::ServerPortForClient");

log_level('debug');
repeat_each($ENV{TEST_NGINX_REPEAT_EACH} || 2);
no_root_location();

our $dns = sub ($$$) {
    my ($host, $ip, $ttl) = @_;

    return sub {
        # Get DNS request ID from passed UDP datagram
        my $dns_id = unpack("n", shift);
        # Set name and encode it
        my $name = $host;
        $name =~ s/([^.]+)\.?/chr(length($1)) . $1/ge;
        $name .= "\0";
        my $s = '';
        $s .= pack("n", $dns_id);
        # DNS response flags, hardcoded
        # response, opcode, authoritative, truncated, recursion desired, recursion available, reserved
        my $flags = (1 << 15) + (0 << 11) + (1 << 10) + (0 << 9) + (1 << 8) + (1 << 7) + 0;
        $flags = pack("n", $flags);
        $s .= $flags;
        $s .= pack("nnnn", 1, 1, 0, 0);
        $s .= $name;
        $s .= pack("nn", 1, 1); # query class A

        # Set response address and pack it
        my @addr = split /\./, $ip;
        my $data = pack("CCCC", @addr);

        # pointer reference to the first name
        # $name = pack("n", 0b1100000000001100);

        # name + type A + class IN + TTL + length + data(ip)
        $s .= $name. pack("nnNn", 1, 1, $ttl || 0, 4) . $data;
        return $s;
    }
};


sub Test::Base::Filter::dns {
    my ($self, $code) = @_;

    my $input = eval $code;

    if ($@) {
        die "failed to evaluate code $code: $@\n";
    }

    return $dns->(@$input)
}

1;

package TestAPIcastBlackbox;
use strict;
use warnings FATAL => 'all';
use v5.10.1;

use lib 't';
use TestAPIcast  -Base;
use File::Copy "move";
use File::Temp qw/ tempfile /;

add_block_preprocessor(sub {
    my $block = shift;
    my $seq = $block->seq_num;
    my $name = $block->name;

    $block->set_value("config", "$name ($seq)");
});

my $write_nginx_config = sub {
    my $block = shift;

    my $ConfFile = $Test::Nginx::Util::ConfFile;
    my $Workers = $Test::Nginx::Util::Workers;
    my $MasterProcessEnabled = $Test::Nginx::Util::MasterProcessEnabled;
    my $DaemonEnabled = $Test::Nginx::Util::DaemonEnabled;
    my $err_log_file = $block->error_log_file || $Test::Nginx::Util::ErrLogFile;
    my $LogLevel = $Test::Nginx::Util::LogLevel;
    my $PidFile = $Test::Nginx::Util::PidFile;
    my $AccLogFile = $Test::Nginx::Util::AccLogFile;
    my $ServerPort = $Test::Nginx::Util::ServerPort;

    my ($conf, $configuration) = tempfile();
    print $conf $block->configuration;
    close $conf;

    open my $out, ">apicast/config/test.lua" or Test::Nginx::Util::bail_out "Can't open $ConfFile for writing: $!\n";

    print $out <<_EOC_;
return {
    worker_processes = '$Workers',
    master_process = '$MasterProcessEnabled',
    daemon = '$DaemonEnabled',
    error_log = '$err_log_file',
    log_level = '$LogLevel',
    pid = '$PidFile',
    lua_code_cache = 'on',
    access_log = '$AccLogFile',
    port = { apicast = '$ServerPort' },
    env = { APICAST_CONFIGURATION = 'file://$configuration', APICAST_CONFIGURATION_LOADER = 'boot' },
}
_EOC_
    close $out;

    my $apicast = `bin/apicast --boot --test --environment test --configuration $configuration 2>&1`;
    if ($apicast =~ /configuration file (?<file>.+?) test is successful/)
    {
        move($+{file}, $Test::Nginx::Util::ConfFile);
    } else {
        warn "Missing config file: $Test::Nginx::Util::ConfFile";
        warn $apicast;
    }
};

BEGIN {
    no warnings 'redefine';

    sub Test::Nginx::Util::write_config_file ($$) {
        my $block = shift;
        return $write_nginx_config->($block);
    }
}

1;

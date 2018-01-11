# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "fedora/26-cloud-base"
  config.vm.box_version = "20170705"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network "private_network", type: 'dhcp'

  config.vm.network "forwarded_port", guest: 8080, host: 8080, auto_correct: true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
   config.vm.provider "virtualbox" do |vb|
     vb.memory = "1024"
     vb.cpus = 2
   end

  # View the documentation for the provider you are using for more
  # information on available options.
  config.vm.synced_folder ".", "/vagrant", type: 'virtualbox'

  config.vm.synced_folder ".", "/home/vagrant/app", type: 'rsync',
    rsync__exclude: %w[lua_modules .git .vagrant node_modules t/servroot t/servroot* ],
    rsync__args: %w[--verbose --archive --delete -z --links ]

  config.vm.provision "shell", inline: <<~'SHELL'
     set -x -e
     dnf -y install dnf-plugins-core

     dnf config-manager --add-repo https://openresty.org/package/fedora/openresty.repo

     yum -y install rsync
     yum -y install openresty-resty openresty-debug openresty-debug-debuginfo openresty-pcre-debuginfo
     yum -y install systemtap git httpd-tools
     yum -y install luarocks
     yum -y install perl-local-lib perl-App-cpanminus redis perl-open expect

     yum -y groupinstall 'Development Tools'
     yum -y install openssl-devel libev-devel

     dnf debuginfo-install -y kernel-core-$(uname -r)

     # Clone various utilities
     git clone https://github.com/openresty/stapxx.git /usr/local/stapxx || (cd /usr/local/stapxx && git pull)
     git clone https://github.com/brendangregg/FlameGraph.git /usr/local/flamegraph || (cd /usr/local/flamegraph && git pull)
     git clone https://github.com/openresty/openresty-systemtap-toolkit.git /usr/local/openresty-systemtap-toolkit || (cd /usr/local/openresty-systemtap-toolkit && git pull)
     curl -L https://github.com/tsenart/vegeta/releases/download/v6.1.1/vegeta-v6.1.1-linux-amd64.tar.gz | tar -xz --overwrite -C /usr/local/bin/

     git clone https://github.com/wg/wrk.git /usr/local/wrk || (cd /usr/local/wrk && git pull)
     ( cd /usr/local/wrk && make && mv wrk /usr/local/bin/ )

     git clone https://github.com/lighttpd/weighttp.git /usr/local/weighttp || (cd /usr/local/weighttp && git pull)
     ( cd /usr/local/weighttp && gcc -O2 -DPACKAGE_VERSION='"0.4"' src/*.c -o weighttp -lev -lpthread && ln -sf $(pwd)/weighttp /usr/local/bin/ )

     # Utility to resolve builtin functions
     echo '#!/usr/bin/env luajit' > /usr/local/bin/ljff
     curl -L https://raw.githubusercontent.com/openresty/openresty-devel-utils/master/ljff.lua >> /usr/local/bin/ljff
     chmod +x /usr/local/bin/ljff

     # Create stap++ executable always pointing to its proper location
     echo '#!/bin/sh' > /usr/local/bin/stap++
     echo 'exec /usr/local/stapxx/stap++ -I /usr/local/stapxx/tapset "$@"' >> /usr/local/bin/stap++
     chmod +x /usr/local/bin/stap++

     echo 'pathmunge lua_modules/bin' > /etc/profile.d/rover.sh
     chmod +x /etc/profile.d/rover.sh

     echo 'eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)' > /etc/profile.d/perl.sh
     chmod +x /etc/profile.d/perl.sh

     mkdir -p /usr/share/lua/5.{1,3}/luarocks/
     curl -L https://raw.githubusercontent.com/3scale/s2i-openresty/ffb1c55533be866a97466915d7ef31c12bae688c/site_config.lua > /usr/share/lua/5.1/luarocks/site_config.lua
     ln -sf /usr/share/lua/5.{1,3}/luarocks/site_config.lua

     # Install APIcast dependencies
     yum -y install python2-pip

     # Add various utilites to the PATH
     ln -sf /usr/local/openresty/luajit/bin/luajit /usr/local/bin/luajit
     ln -sf /usr/local/flamegraph/*.pl /usr/local/bin/
     ln -sf /usr/local/stapxx/samples/*.sxx /usr/local/bin/
     ln -sf `find -O0 /usr/local/openresty-systemtap-toolkit/ -maxdepth 1 -type f -executable -print` /usr/local/bin/

     # Allow vagrant user to use systemtap
     usermod -a -G stapusr,stapdev vagrant

     # Raise opened files limit for vagrant user
     echo -e 'vagrant\t\t\t-\tnofile\t\t1000000' > /etc/security/limits.d/90-nofile.conf

     echo 'kernel.perf_event_paranoid = -1' > /etc/sysctl.d/perf.conf
     echo -1 > /proc/sys/kernel/perf_event_paranoid

     # Start redis needed for tests
     systemctl  start redis
     systemctl disable openresty
     systemctl stop openresty
SHELL

  config.vm.provision 'shell', privileged: false, name: "Install APIcast dependencies", inline: <<~'SHELL'
    set -x -e
    pip install --user hererocks
    pushd app
    hererocks lua_modules -r^ -l 5.1 --no-readline
    curl -L https://raw.githubusercontent.com/3scale/s2i-openresty/ffb1c55533be866a97466915d7ef31c12bae688c/site_config.lua -o lua_modules/share/lua/5.1/luarocks/site_config.lua
    make dependencies cpan

    mkdir -p ~/.systemtap
    # needed for complete backtraces
    # increase this if you start seeing stacks collapsed in impossible ways
    # also try https://github.com/openresty/stapxx/commit/59ba231efba8725a510cd8d1d585aedf94670404
    # to avoid MAXACTTION problems
    cat <<- EOF > ~/.systemtap/rc
    -D MAXSTRINGLEN=1024
    EOF
SHELL
end

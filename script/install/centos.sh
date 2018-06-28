#!/bin/sh

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

dnf debuginfo-install -y "kernel-core-$(uname -r)"

yum -y install python2-pip

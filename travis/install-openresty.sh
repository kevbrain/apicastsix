#!/bin/sh
set -eux

PREFIX=${1:-$HOME/openresty}

if [ ! -d "${PREFIX}/bin" ]; then
  cd /tmp/
  wget -T 60 -q -c http://openresty.org/download/${OPENRESTY_VERSION}.tar.gz
  tar -xzf ${OPENRESTY_VERSION}.tar.gz
  rm -rf ${OPENRESTY_VERSION}.tar.gz
  cd ${OPENRESTY_VERSION}
  ./configure --prefix="${PREFIX}" --with-luajit-xcflags=-DLUAJIT_ENABLE_LUA52COMPAT --with-debug
  make -j$(cat /proc/cpuinfo  | grep -c processor)
  make install
  ln -sf "${PREFIX}"/luajit/bin/luajit-* "${PREFIX}/luajit/bin/luajit"
  ln -sf "${PREFIX}"/luajit/include/luajit-* "${PREFIX}/luajit/include/lua5.1"
else
  echo "Using cached openresty."
fi

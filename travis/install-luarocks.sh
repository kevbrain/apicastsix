#!/bin/sh
set -eux

PREFIX=${1:-$HOME/openresty/luajit}

if [ ! -d "${PREFIX}/share/lua/5.1/luarocks" ]; then
  cd /tmp/
  wget -T 60 -q -c https://github.com/keplerproject/luarocks/archive/v${LUAROCKS_VERSION}.tar.gz
  tar -xzf v${LUAROCKS_VERSION}.tar.gz
  rm -rf v${LUAROCKS_VERSION}.tar.gz
  cd luarocks-${LUAROCKS_VERSION}
  ./configure \
    --prefix="${PREFIX}" \
    --with-lua="${PREFIX}" \
    --with-lua-lib="${HOME}/openresty/lualib" \
    --lua-suffix=jit \
    --lua-version=5.1
  make build
  make install
else
  echo "Using cached luarocks."
fi

#!/bin/sh
set -eux

PREFIX=${1:-$HOME/openresty}
OPENRESTY_VERSION=$(echo "${OPENRESTY_VERSION}" | cut -f1 -d-)
OPENRESTY_ARCHIVE="openresty-${OPENRESTY_VERSION}"
OPENRESTY="${PREFIX}/bin/openresty"

if [ -f "${OPENRESTY}" ] && ("${OPENRESTY}" -v 2>&1 | grep "${OPENRESTY_VERSION}" > /dev/null); then
  echo "Using cached openresty."
  "${OPENRESTY}" -V
else
  wget -T 60 -q -c "http://openresty.org/download/${OPENRESTY_ARCHIVE}.tar.gz"
  tar -xzf "${OPENRESTY_ARCHIVE}.tar.gz"
  rm -rf "${OPENRESTY_ARCHIVE}.tar.gz"
  cd "${OPENRESTY_ARCHIVE}"
  ./configure --prefix="${PREFIX}" --with-ipv6 --with-luajit-xcflags=-DLUAJIT_ENABLE_LUA52COMPAT --with-debug
  make "-j$(grep -c processor /proc/cpuinfo)"
  make install
  ln -sf "${PREFIX}"/luajit/bin/luajit-* "${PREFIX}/luajit/bin/luajit"
  ln -sf "${PREFIX}"/luajit/include/luajit-* "${PREFIX}/luajit/include/lua5.1"

  # If resty does resolve ipv6 by default (<= 0.16) disable it
  if ! (grep resolve_ipv6 "${PREFIX}/bin/resty"); then
    sed -i.bak 's/my @nameservers;/my @nameservers = ("ipv6=off");/' "${PREFIX}/bin/resty"
  fi
fi

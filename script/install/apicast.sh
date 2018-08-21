#!/bin/sh

set -x -e
pip install --user hererocks

if [ -n "$1" ]; then
  cd "$1"
fi

"$HOME/.local/bin/hererocks" lua_modules -r^ -l 5.1 --no-readline
curl -L https://raw.githubusercontent.com/3scale/s2i-openresty/ffb1c55533be866a97466915d7ef31c12bae688c/site_config.lua -o lua_modules/share/lua/5.1/luarocks/site_config.lua
make lua_modules cpan

mkdir -p ~/.systemtap
# needed for complete backtraces
# increase this if you start seeing stacks collapsed in impossible ways
# also try https://github.com/openresty/stapxx/commit/59ba231efba8725a510cd8d1d585aedf94670404
# to avoid MAXACTTION problems
cat <<- EOF > ~/.systemtap/rc
-D MAXSTRINGLEN=1024
EOF

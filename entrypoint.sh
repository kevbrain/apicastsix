#!/usr/local/bin/dumb-init /bin/sh


# 3scale (operations@3scale.net)
set -eu

# Load Luarocks paths
eval `/opt/app/bin/luarocks path`

if [ "${AUTO_UPDATE_INTERVAL}" != 0 ] && [ "${AUTO_UPDATE_INTERVAL}" -lt 60 ]; then
  echo "AUTO_UPDATE_INTERVAL should be 60 or greater"
  exit 1
fi

pick_dns_server() {
  DNS=$(grep nameserver /etc/resolv.conf | awk {'print $2'})

  if [ -z "$DNS" ]; then
    echo "127.0.0.1"
  else
    for server in $DNS; do
      nslookup redhat.com "$server" &> /dev/null
      if [ $? -eq 0 ]; then
        echo "$server"
        break
      fi
    done
  fi
}


export NAMESERVER

NAMESERVER=$(pick_dns_server)

export RESOLVER=${RESOLVER:-${NAMESERVER}}

mkdir -p /opt/app/http.d
echo "resolver ${RESOLVER};" > /opt/app/http.d/resolver.conf

exec openresty -p /opt/app/ -c nginx.conf "$@"

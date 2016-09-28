#!/bin/sh

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
      if (nslookup -timeout=1 -retry=3 redhat.com "$server" &> /dev/null); then
        echo "$server"
	 exit 0
      fi
    done

    (>&2 echo "error: no working DNS server found")
    exit 1
  fi
}


export NAMESERVER

NAMESERVER=$(pick_dns_server)

export RESOLVER=${RESOLVER:-${NAMESERVER}}

mkdir -p /opt/app/http.d
echo "resolver ${RESOLVER};" > /opt/app/http.d/resolver.conf

if [ -z "${THREESCALE_PORTAL_ENDPOINT:-}" ] && [ -z "${THREESCALE_CONFIG_FILE:-}" ]; then
  # TODO: improve the error messsage
  echo "missing either THREESCALE_PORTAL_ENDPOINT or THREESCALE_CONFIG_FILE envirionment variable"
  exit 1
fi

exec bin/apicast "$@"

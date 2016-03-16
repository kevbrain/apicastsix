#!/bin/sh -u
# 3scale (operations@3scale.net)

mkdir /opt/openresty/nginx/lua/

reload_openresty() {
  echo "Reloading Openresty"
  pkill -USR1 -o nginx
}

download_threescale_config() {
  echo "Downloading threescale configuration, using endpoint: ${THREESCALE_ENDPOINT}"
  cd /tmp
  rm -rf /tmp/${THREESCALE_PROVIDER_KEY}/
  mkdir -p /tmp/${THREESCALE_PROVIDER_KEY}/
  curl  ${THREESCALE_ENDPOINT}/admin/api/nginx.zip?provider_key=${THREESCALE_PROVIDER_KEY} -o /tmp/${THREESCALE_PROVIDER_KEY}/nginx.zip
  cd /tmp/${THREESCALE_PROVIDER_KEY}/
  unzip nginx.zip && rm nginx.zip
}

deploy_threescale_config() {
  echo "Deploying new configuration"
  cd /tmp/${THREESCALE_PROVIDER_KEY}/
  cp -f nginx_*.conf /opt/openresty/nginx/conf/nginx.conf
  cp -f nginx_*.lua /opt/openresty/lualib/
}

compare_threescale_config() {
  CURRENT_CONF_FILE=/opt/openresty/nginx/conf/nginx.conf
  NEW_CONF_FILE=/tmp/${THREESCALE_PROVIDER_KEY}/nginx_*.conf
  CURRENT_LUA_FILE=/opt/openresty/lualib/nginx_*.lua
  NEW_LUA_FILE=/tmp/${THREESCALE_PROVIDER_KEY}/nginx_*.lua
  CHANGES=0

  diff -I "proxy_set_header  X-3scale-Version" $CURRENT_CONF_FILE $NEW_CONF_FILE
  if [ $? -eq 1 ]; then
    CHANGES=1
  fi

  diff $NEW_LUA_FILE $NEW_LUA_FILE
  if [ $? -eq 1 ]; then
    CHANGES=1
  fi

  if [ $CHANGES = 1 ]; then
    echo "Changes detected, deploying new configuration"
    deploy_threescale_config
    reload_openresty
  fi
}

download_threescale_config
deploy_threescale_config

#Run nginx.
cd ${NGINX_PREFIX}
nginx -g "daemon off; error_log /dev/stderr info;" &

trap 'kill ${!}; reload_openresty' SIGUSR1
trap 'kill ${!}; download_threescale_config; deploy_threescale_config; reload_openresty' SIGUSR2

while true
do
  if [ ${AUTO_UPDATE} = true ]; then
    for i in $(seq 1 $CHECK_TIMER);do sleep 1; done
    download_threescale_config
    compare_threescale_config
  else
    tail -f /dev/null & wait ${!}
  fi
done

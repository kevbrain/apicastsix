#!/usr/local/bin/dumb-init /bin/sh
# 3scale (operations@3scale.net)
set -u

if [ ${AUTO_UPDATE_INTERVAL} != 0 ] && [ ${AUTO_UPDATE_INTERVAL} -lt 60 ]; then
	echo "AUTO_UPDATE_INTERVAL should be 60 or greater"
	exit 1
fi

reload_openresty() {
  echo "Reloading Openresty"
  pkill -HUP -o nginx
}

download_threescale_config() {
	TEMP_DIR=`mktemp -d`
  echo "Downloading threescale configuration, using endpoint: ${THREESCALE_ENDPOINT}"
  curl  ${THREESCALE_ENDPOINT}/admin/api/nginx.zip?provider_key=${THREESCALE_PROVIDER_KEY} -o $TEMP_DIR/nginx.zip
	cd $TEMP_DIR
	unzip nginx.zip
}

deploy_threescale_config() {
  echo "Deploying new configuration"
  cp -f $TEMP_DIR/nginx_*.conf /opt/openresty/nginx/conf/nginx.conf
  cp -f $TEMP_DIR/nginx_*.lua /opt/openresty/lualib/
	reload_openresty
}

compare_threescale_config() {

	download_threescale_config

  CURRENT_CONF_FILE=/opt/openresty/nginx/conf/nginx.conf
  NEW_CONF_FILE=$TEMP_DIR/nginx_*.conf
  CURRENT_LUA_FILE=/opt/openresty/lualib/nginx_*.lua
  NEW_LUA_FILE=$TEMP_DIR/nginx_*.lua
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

nginx -g "daemon off; error_log /dev/stderr info;" &

download_threescale_config
deploy_threescale_config

trap 'download_threescale_config; deploy_threescale_config;' SIGUSR1
trap '' SIGHUP
trap '' SIGUSR2
trap '' WINCH

while true
do
  if [ ${AUTO_UPDATE_INTERVAL} -ge 60 ]; then
    for i in $(seq 1 ${AUTO_UPDATE_INTERVAL}); do sleep 1; done
    compare_threescale_config
    rm -rf $TEMP_DIR
  else
    tail -f /dev/null & wait ${!}
  fi
done

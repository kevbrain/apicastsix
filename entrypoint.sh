#!/bin/sh -u

cd /tmp/

# Download config files
curl  ${THREESCALE_ENDPOINT}/admin/api/nginx.zip?provider_key=${THREESCALE_PROVIDER_KEY} -o /tmp/nginx.zip
unzip nginx.zip && rm /tmp/nginx.zip

mkdir /opt/openresty/nginx/lua/

cp nginx_*.conf /opt/openresty/nginx/conf/nginx.conf
cp nginx_*.lua /opt/openresty/lualib/

rm -rf /tmp/*

#Run nginx.
cd ${NGINX_PREFIX}
nginx -g "daemon off; error_log /dev/stderr info;"


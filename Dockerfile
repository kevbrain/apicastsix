FROM alpine:3.3
MAINTAINER 3scale <operations@3scale.net>

ENV OPENRESTY_VERSION=1.9.7.3 NGINX_PREFIX=/opt/openresty/nginx AUTO_UPDATE_INTERVAL=0

EXPOSE 8080

RUN adduser -S openresty

# Based on https://github.com/ficusio/openresty
RUN export OPENRESTY_PREFIX=/opt/openresty VAR_PREFIX=/var/nginx \
 && apk update \
 && apk add --virtual build-deps \
    make gcc musl-dev \
    pcre-dev openssl-dev zlib-dev ncurses-dev readline-dev \
    perl \
 && apk add gettext curl unzip diffutils \
 && cp -v /usr/bin/envsubst /usr/local/bin/ \
 && mkdir -p /root/ngx_openresty \
 && cd /root/ngx_openresty \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && cd openresty-* \
 && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
    --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
    --http-log-path=$VAR_PREFIX/access.log \
    --error-log-path=$VAR_PREFIX/error.log \
    --pid-path=$VAR_PREFIX/nginx.pid \
    --lock-path=$VAR_PREFIX/nginx.lock \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_ssl_module \
    --without-http_ssi_module \
    --without-http_userid_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    -j${NPROC} \
 && make -j${NPROC} \
 && make install \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua \
 && apk del build-deps \
 && apk add \
    libpcrecpp libpcre16 libpcre32 openssl libssl1.0 pcre libgcc libstdc++ \
 && rm -rf /var/cache/apk/* \
 && rm -rf /root/ngx_openresty \
 && curl -L https://github.com/Yelp/dumb-init/releases/download/v1.0.1/dumb-init_1.0.1_amd64 -o /usr/local/bin/dumb-init \
 && chmod a+x /usr/local/bin/dumb-init

RUN chown openresty -R /var/nginx ; chown openresty -R /opt/openresty 

#Openshift v3 patch
RUN chmod og+w -R /opt/openresty /var/nginx
USER openresty

COPY entrypoint.sh /

WORKDIR $NGINX_PREFIX/

LABEL io.k8s.description 3scale Gateway
LABEL io.openshift.expose-services 8080:http

ENTRYPOINT ["/entrypoint.sh"]

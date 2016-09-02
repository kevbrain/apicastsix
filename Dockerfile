FROM centos:7
MAINTAINER 3scale <operations@3scale.net>

ARG OPENRESTY_RPM_VERSION="1.11.2.1-3.el7.centos"
ARG LUAROCKS_VERSION="2.3.0"
ENV AUTO_UPDATE_INTERVAL=0 NGINX_PREFIX=/usr/local/openresty/nginx LUALIB_PREFIX=/usr/local/openresty/lualib

EXPOSE 8080

ADD openresty.repo /etc/yum.repos.d/openresty.repo

WORKDIR /tmp

RUN yum install -y \
        make \
        unzip \
        git \
        wget \
        bind-utils \ 
        openresty-${OPENRESTY_RPM_VERSION} \
        openresty-resty-${OPENRESTY_RPM_VERSION} \
    && wget https://github.com/Yelp/dumb-init/releases/download/v1.0.1/dumb-init_1.0.1_amd64 -O /usr/local/bin/dumb-init \
    && chmod a+x /usr/local/bin/dumb-init \
    && wget http://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz \
    && tar -xzvf luarocks-${LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${LUAROCKS_VERSION}/ \
    && ./configure --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit-2.1.0-beta2 \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make \ 
    && make install \
    && rm -rf /tmp/* \
    && yum remove -y make \
    && yum clean all \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

#Openshift v3 patch
RUN chmod og+w -R /usr/local/openresty/
USER 1001

COPY entrypoint.sh /

WORKDIR $NGINX_PREFIX/

LABEL io.k8s.description 3scale Gateway
LABEL io.openshift.expose-services 8080:http

ENTRYPOINT ["/entrypoint.sh"]

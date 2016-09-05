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
    && ./configure --prefix=/opt/app --sysconfdir=/opt/app/luarocks --force-config \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
        --with-lua-version=5.1 \
    && make build \
    && make install \
    && rm -rf /tmp/* \
    && yum remove -y make \
    && yum clean all \
    && mkdir -p /opt/app/logs \
    && ln -sf /dev/stdout /opt/app/logs/access.log \
    && ln -sf /dev/stderr /opt/app/logs/error.log

LABEL io.k8s.description 3scale Gateway
LABEL io.openshift.expose-services 8080:http

ADD . /opt/app
WORKDIR /opt/app/

RUN chmod g+w /opt/app/ /opt/app/http.d/resolver.conf /opt/app/logs/

USER 1001

ENTRYPOINT ["/opt/app/entrypoint.sh"]
CMD ["-g", "daemon off;"]

FROM openresty/openresty:1.21.4.1-0-alpine-fat

ENV ENV dev
ENV APP_TYPE bts
ENV NGINX_CONF_FILENAME default
ENV LUA_FILENAME default

RUN opm install timebug/lua-resty-redis-ratelimit

VOLUME [ "/var/run/openresty" ]
VOLUME [ "/etc/nginx/ssl" ]
VOLUME [ "/etc/nginx/conf.d" ]

RUN mkdir -p /etc/nginx/lua && \
    mkdir -p /etc/nginx/ssl && \
    mkdir -p /etc/nginx/conf.d && \
    mkdir /conf && \
    mkdir /lua

ADD conf /conf
ADD scripts/lua /lua
COPY scripts/entry.sh /usr/local/bin/entry.sh

CMD ["/usr/local/bin/entry.sh"]
# Openresty

## Description

This repo is to set some lua rules by Openresty
as a proxy layer in front of my services.

The Steem services are include:

- [x] bts

## Manual

### Create folders

```
mkdir -p conf/APP_TYPE
mkdir -p scripts/lua/APP_TYPE
```

Replace `APP_TYPE` with your requirement.


### Add Openresty config
```
touch conf/APP_TYPE/nginx.conf
touch conf/APP_TYPE/default.conf
```

The `nginx.conf` is the main configure file of Openresty.
The `default.conf` is the host configure file of service.

These two files **MUST** exist.

### Add lua script

```
touch scripts/lua/APP_TYPE/WHAT_YOU_WANT_TO_ADD.lua
```

When container starts, all lua scripts in `scripts/lua/APP_TYPE`
will copy to `/etc/nginx/lua/`.

You could import them in your `default.conf`.

### Add layer config into docker-compose.yaml file of the service

```
version: '3.8'
services:
  openresty:
    image: "ety001/openresty:latest"
    ports:
      - "80:80"
    environment:
      APP_TYPE: "bts"
    volumes:
      - /dev/shm/openresty:/var/run/openresty
    logging:
      driver: "syslog"
      options:
        tag: "openresty"
    env_file:
      - .env
```

The param What you should edit is the `APP_TYPE`.

## Other Things

Temporary directories such as `client_body_temp_path` are stored
in `/var/run/openresty/`. You may consider mounting that volume,
rather than writing to a container-local directory. 
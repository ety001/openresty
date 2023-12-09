#!/bin/ash

# The default config is bts
if [ -z "${APP_TYPE}" ]; then
    export APP_TYPE=bts
fi

if [ -z "${NGINX_CONF_FILENAME}" ]; then
    export NGINX_CONF_FILENAME=default
fi

nginx_conf_path=/conf/${APP_TYPE}
lua_script_path=/lua/${APP_TYPE}

if [ -e "${nginx_conf_path}/nginx.conf" ]; then
    cp ${nginx_conf_path}/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
else
    echo "[ERROR] ${nginx_conf_path}/nginx.conf not exists"  
    exit 1
fi

if [ -e "${nginx_conf_path}/${NGINX_CONF_FILENAME}.conf" ]; then
    if [ -e "/etc/nginx/conf.d/${NGINX_CONF_FILENAME}.conf" ]; then
        echo "[INFO] has mounted config files."
    else
        echo "[INFO] use default config files."
        cp ${nginx_conf_path}/${NGINX_CONF_FILENAME}.conf /etc/nginx/conf.d/${NGINX_CONF_FILENAME}.conf
    fi
else
    echo "[ERROR] ${nginx_conf_path}/${NGINX_CONF_FILENAME}.conf not exists"  
    exit 1
fi

if [ "`ls /etc/nginx/lua`" = "" ]; then
    echo "[INFO] use default lua scripts."
    cp -f ${lua_script_path}/*.lua /etc/nginx/lua/
fi

/usr/local/openresty/bin/openresty -g "daemon off;"
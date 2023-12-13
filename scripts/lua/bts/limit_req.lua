-- This is a demo config
-- You need create your config file and mount it into container `/etc/nginx/lua`

local cjson = require "cjson"
local server = require "resty.websocket.server"
local client = require "resty.websocket.client"
local ratelimit = require "resty.redis.ratelimit"
local new_tab = require "table.new"

-- nginx client info
local real_client_ip = ngx.var.http_x_real_ip or ngx.var.http_x_forwarded_for or ngx.var.remote_addr
local upgrade_header = ngx.req.get_headers()["Upgrade"]

-- websocket conf
local ws_timeout = 60 * 1000
local ws_max_payload_len = 2 * 1024 * 1024

-- rate limit settings
local rate_burst = 50
local rate_duration = 1

-- redis conf
local redis_host = "172.20.0.15"

-- api list
local api_list = new_tab(7, 0)
api_list["get_assets"] = "50r/s"
api_list["list_liquidity_pools"] = "50r/s"
api_list["get_liquidity_pools_by_asset_b"] = "50r/s"
api_list["get_account_history"] = "50r/s"
api_list["get_full_accounts"] = "50r/s"
api_list["get_ticker"] = "50r/s"
api_list["get_transaction_hex_without_sig"] = "50r/s"

-- bot list
local bots = new_tab(2, 0)
bots["162.62.217.73"] = true
bots["23.166.40.37"] = true

if upgrade_header and upgrade_header:lower() == "websocket" then
    -- websocket handler
    -- init ws server
    local frontend, err = server:new{
        max_payload_len = ws_max_payload_len,
        timeout = ws_timeout,
    }
    if not frontend then
        ngx.log(ngx.ERR, "failed to new websocket: ", err)
        return ngx.exit(444)
    end
    
    -- init backend ws client
    local backend_url = "ws://172.20.0.10:8090/ws"
    local backend, err = client:new{
        max_payload_len = ws_max_payload_len,
        timeout = ws_timeout,
    }
    local ok, err = backend:connect(backend_url)
    if not ok then
        ngx.say("failed to connect backend: " .. err)
        return
    end
    
    -- main logic
    while true do
        -- process receive data
        local req_data, typ, err = frontend:recv_frame()
        if err then
            ngx.log(ngx.ERR, "failed to receive frame: ", err)
            return ngx.exit(444)
        end
        if typ == "close" then
            break
        end

        -- parse json data
        local parsed_data = cjson.decode(req_data)
        local parsed_method = parsed_data.method
        local parsed_params = parsed_data.params
        if parsed_method == "call" then
            parsed_method = parsed_params[2]
            parsed_params = parsed_params[3]
        end
        -- ngx.log(ngx.NOTICE, "--00-- parsed data --00--:", parsed_method, cjson.encode(parsed_params))

        -- limit logic
        if bots[real_client_ip] and parsed_method and api_list[parsed_method] then
            -- ngx.log(ngx.NOTICE, "--01-- process " .. parsed_method .. "--01--:", cjson.encode(parsed_params))
            local rate_limit = api_list[parsed_method]
            local lim, err = ratelimit.new("bts", rate_limit, rate_burst, rate_duration)
            if not lim then
                local result = {
                    id = -1,
                    code = -32801,
                    error = {
                        data = err,
                        message = "failed to instantiate a resty.redis.ratelimit object",
                    }
                }
                ngx.log(ngx.ERR, "rejected a request caused by rate limit:" .. parsed_method)
                frontend:send_text(cjson.encode(response))
                goto continue
            end

            local redis_config = { host = redis_host, port = 6379, timeout = 1, dbid = 2 }
            local key = parsed_method .. ":" .. real_client_ip
            local delay, err = lim:incoming(key, redis_config)
            if not delay then
                if err == "rejected" then
                    local result = {
                        id = -1,
                        code = -32801,
                        error = {
                            message = "method [" .. parsed_method .. "] is limited by " .. rate_limit .. " per ip",
                        }
                    }
                    ngx.log(ngx.ERR, "rejected a request caused by rate limit:" .. parsed_method)
                    frontend:send_text(cjson.encode(response))
                    goto continue
                end
                local result = {
                    id = -1,
                    code = -32801,
                    error = {
                        data = err,
                        message = "failed to limit req",
                    }
                }
                ngx.log(ngx.ERR, "failed to limit req: " .. parsed_method, err)
                frontend:send_text(cjson.encode(response))
                goto continue
            end
            if delay >= 0.001 then
                ngx.sleep(delay)
            end
        end

        -- send message to backend
        backend:send_text(req_data)

        -- receive date from backend
        local response, typ, err = backend:recv_frame()
        if err then
            ngx.log(ngx.ERR, "failed to receive frame from backend: ", err)
            return ngx.exit(444)
        end
    
        -- transfer backend data to frontend
        frontend:send_text(response)

        ::continue::
    end
else
    -- http request handler
    ngx.log(ngx.NOTICE, "http request")
    ngx.exec("/normal")
end
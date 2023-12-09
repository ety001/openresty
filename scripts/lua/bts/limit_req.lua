local cjson = require "cjson"
-- jsonrpc error code
local jsonrpc_err_code = -32801
-- upper limit setting
local account_history_upper_threshold = 20

local limit_req = require "resty.limit.req"
local rate = 10 
local lim, err = limit_req.new("limit_req_store", rate, 2) -- rate each second, leaky bucket capacity
if not lim then
    ngx.log(ngx.ERR,"failed to create resty.limit.req: " .. err)
    return ngx.exit(503)
end

-- init api_list
local new_tab = require "table.new"
local api_list = new_tab(3, 0)
api_list["condenser_api.get_account_history"] = true
api_list["account_history_api.get_account_history"] = true
api_list["condenser_api.get_ops_in_block"] = true

local req_data = ngx.req.get_body_data()
if req_data then
    local data = cjson.decode(req_data)
    if data.method then
        local method_str = data.method
        local params = data.params
        if data.method == "call" then
            method_str = data.params[1] .. "." .. data.params[2]
            params = data.params[3]
        end
        -- analytics
        ngx.log(ngx.NOTICE, "analytics_method:" .. method_str .. " analytics_params:" .. cjson.encode(params))
        -- trigger limit (condenser_api.get_account_history)
        if method_str and method_str == "condenser_api.get_account_history" then
            if params[3] == cjson.null then
                local result = {
                    jsonrpc = "2.0",
                    error = {
                        code = jsonrpc_err_code,
                        message = "condenser_api.get_account_history params error.",
                        id = 1
                    }
                }
                ngx.log(ngx.NOTICE,
                    "condenser_api.get_account_history params null.")
                return ngx.say(cjson.encode(result))
            end
            if params[3] > account_history_upper_threshold then
                local result = {
                    jsonrpc = "2.0",
                    error = {
                        code = jsonrpc_err_code,
                        message = "condenser_api.get_account_history upper limit is " .. account_history_upper_threshold,
                        id = 1
                    }
                }
                ngx.log(ngx.NOTICE,
                    "trigger threshold of condenser_api.get_account_history upper limit")
                return ngx.say(cjson.encode(result))
            end
        end
        -- trigger limit (account_history_api.get_account_history)
        if method_str and method_str == "account_history_api.get_account_history" then
            if params.limit > account_history_upper_threshold then
                local result = {
                    jsonrpc = "2.0",
                    error = {
                        code = jsonrpc_err_code,
                        message = "account_history_api.get_account_history upper limit is " .. account_history_upper_threshold,
                        id = 1
                    }
                }
                ngx.log(ngx.NOTICE,
                    "trigger threshold of account_history_api.get_account_history upper limit")
                return ngx.say(cjson.encode(result))
            end
        end
        if api_list[method_str] then
            local key = method_str .. "_" .. ngx.var.binary_remote_addr
            local delay, err = lim:incoming(key, true)
            if not delay then
                if err == "rejected" then
                    local result = {
                        jsonrpc = "2.0",
                        error = {
                            code = jsonrpc_err_code,
                            message = "this method is limited by " .. rate .. "times / second / ip",
                            id = 1
                        }
                    }
                    ngx.log(ngx.NOTICE, "rejected a request of " .. method_str)
                    return ngx.say(cjson.encode(result))
                end
                ngx.log(ngx.ERR,"failed to limit req: " .. err)
                return ngx.exit(503)
            end

            if delay >= 0.001 then
                ngx.log(ngx.NOTICE, "rejected a request for " .. delay .. " seconds")
                ngx.sleep(delay)
            end
        end
    end
end
ngx.exec("/upstream")
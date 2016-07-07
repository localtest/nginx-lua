--[[

server {
	listen       80;
	server_name  xxx.xxx.com;

	location /proxy/ {
		internal;
		rewrite ^/proxy/(https?)/(.*)/(\d+)/(.*)     /$4 break;
		return 400;
		proxy_set_header Host $host:$3;
		proxy_set_header Accept-Encoding '';
		proxy_pass      $1://$2:$3;
		more_set_headers  "Bench-request_time: $request_time";
		more_set_headers  "Bench-body_bytes_sent: $body_bytes_sent";
		more_set_headers  "Bench-upstream_response_time: $upstream_response_time";
		more_set_headers  "Bench-msec: $msec";
		more_set_headers  "Bench-upstream_addr: $upstream_addr";
		more_set_headers  "Bench-upstream_status: $upstream_status";

		#For debug
		#more_set_headers  "Bench-request: $request";
		#more_set_headers  "Bench-host: $host:$3";
		#more_set_headers  "Bench-proxy_pass: $1://$2:$3";
	}
	location / {
		default_type 'text/html';
		lua_code_cache off;
		content_by_lua_file /path/to/bench.lua;
	}
}

--]]

-- HTTP Headers
local headers = ngx.req.get_headers()
local req_host;
local port_pos;
local req_port;
for key, value in pairs(headers) do
  --[[
  if key=='host' then
    port_pos = string.find(value, ':');
    if port_pos ~=nil then
      req_host = string.sub(value, 0, port_pos-1);
      req_port = string.sub(value, port_pos+1);
      value = req_host;
    end
  end
  --]]
ngx.req.set_header(key, value);
end


local request_method = ngx.var.request_method;
local http_method;

-- HTTP Method
if request_method == 'GET' then
  http_method = ngx.HTTP_GET
elseif request_method == 'HEAD' then
  http_method = ngx.HTTP_HEAD
elseif request_method == 'PUT' then
  http_method = ngx.HTTP_PUT
elseif request_method == 'POST' then
  http_method = ngx.HTTP_POST
elseif request_method == 'DELETE' then
  http_method = ngx.HTTP_DELETE
elseif request_method == 'OPTIONS' then
  http_method = ngx.HTTP_OPTIONS
elseif request_method == 'MKCOL' then
  http_method = ngx.HTTP_MKCOL
elseif request_method == 'COPY' then
  http_method = ngx.HTTP_COPY
elseif request_method == 'MOVE' then
  http_method = ngx.HTTP_MOVE
elseif request_method == 'PROPFIND' then
  http_method = ngx.HTTP_PROPFIND
elseif request_method == 'PROPPATCH' then
  http_method = ngx.HTTP_PROPPATCH
elseif request_method == 'LOCK' then
  http_method = ngx.HTTP_LOCK
elseif request_method == 'UNLOCK' then
  http_method = ngx.HTTP_UNLOCK
elseif request_method == 'PATCH' then
  http_method = ngx.HTTP_PATCH
elseif request_method == 'TRACE' then
  http_method = ngx.HTTP_TRACE
end

-- args
local request_args = ngx.req.get_uri_args()
local request_uri = ngx.var.request_uri;
local body = ngx.req.read_body();

-- Bench URL
local proxy_addr, proxy_addr_bench;
proxy_addr = "/proxy/http/api.xxx.com/80"..request_uri;
proxy_addr_bench = "/proxy/http/api2.xxx.com/80"..request_uri;

-- nginx subrequest
local res1;
local res2;
-- 暂未检测, 转发https协议
res1, res2 = ngx.location.capture_multi {
  {
    proxy_addr,
    {
      method = http_method,
      args = request_args,
      body = body,
    }
  },
  {
    proxy_addr_bench,
    {
      method = http_method,
      args = request_args,
      body = body,
    }
  },
}
local h = res1.header
local h2 = res2.header

h['Bench-upstream_status'] = tonumber(h['Bench-upstream_status']);
h['Bench-request_time'] = tonumber(h['Bench-request_time']);
h['Bench-body_bytes_sent'] = tonumber(h['Bench-body_bytes_sent']);

h2['Bench-upstream_status'] = tonumber(h2['Bench-upstream_status']);
h2['Bench-request_time'] = tonumber(h2['Bench-request_time']);
h2['Bench-body_bytes_sent'] = tonumber(h2['Bench-body_bytes_sent']);

local all = {};
all['request_time'] = tonumber(ngx.var.request_time);
all['body_bytes_sent'] = tonumber(ngx.var.body_bytes_sent);
-- perf check
--[[
ngx.say("api|"..h['Bench-upstream_addr'].."|"..h['Bench-upstream_status'].."|"..h['Bench-request_time'].."|"..h['Bench-body_bytes_sent']);
ngx.say("302|"..h2['Bench-upstream_addr'].."|"..h2['Bench-upstream_status'].."|"..h2['Bench-request_time'].."|"..h2['Bench-body_bytes_sent']);
ngx.say("all|"..ngx.var.request_time.."|"..ngx.var.body_bytes_sent);
]]--



local cjson = require "cjson.safe"
local api_data1, error = cjson.decode(res1.body);
local api_data2, error = cjson.decode(res2.body);

------
-- Consistency Check
------
local api_result = {};

-- Equal Check
local equal_fields = {'status'};
for key, field in pairs(equal_fields) do
	if api_data1[field] ~= api_data2[field] then
		api_result['status'] = 5001;
		api_result['msg'] = 'Field not match';
		api_result['field'] = field;
		api_result['val_diff'] = {};
		api_result['val_diff']['api_1'] = api_data1[field];
		api_result['val_diff']['api_2'] = api_data2[field];
		local json_result = cjson.encode(api_result);
		ngx.say(json_result);
		ngx.exit(200);
	end
end

--------------
-- API Report
--------------
api_result['status'] = 200;
api_result['msg'] = 'OK';
api_result['result'] = {};
api_result['result']['api_1'] = {};
api_result['result']['api_1']['addr'] = h['Bench-upstream_addr'];
api_result['result']['api_1']['status'] = h['Bench-upstream_status'];
api_result['result']['api_1']['request_time'] = h['Bench-request_time'];
api_result['result']['api_1']['body_bytes_sent'] = h['Bench-body_bytes_sent'];
api_result['result']['api_2'] = {};
api_result['result']['api_2']['addr'] = h2['Bench-upstream_addr'];
api_result['result']['api_2']['status'] = h2['Bench-upstream_status'];
api_result['result']['api_2']['request_time'] = h2['Bench-request_time'];
api_result['result']['api_2']['body_bytes_sent'] = h2['Bench-body_bytes_sent'];
api_result['result']['sum'] = {};
api_result['result']['sum']['request_time'] = all['request_time'];
api_result['result']['sum']['body_bytes_sent'] = all['body_bytes_sent'];

api_result['report'] = {};
api_result['report']['time'] = {};
api_result['report']['time']['minus'] = h['Bench-request_time'] - h2['Bench-request_time'];
api_result['report']['time']['winner'] = api_result['report']['time']['minus']<0 and 'api_1' or 'api_2';

api_result['report']['status'] = {};
api_result['report']['status']['non_200'] = {};
if h['Bench-upstream_status'] ~= 200 then
	api_result['report']['status']['non_200']['api_1'] = h['Bench-upstream_status'];
end
if h2['Bench-upstream_status'] ~= 200 then
	api_result['report']['status']['non_200']['api_2'] = h2['Bench-upstream_status'];
end

json_result = cjson.encode(api_result);
ngx.say(json_result);
ngx.exit(200);
return;

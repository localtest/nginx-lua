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

local proxy_addr, proxy_addr_bench;
proxy_addr = "/proxy/http/10.13.3.40/8081"..request_uri;
proxy_addr_bench = "/proxy/http/10.13.3.40/8082"..request_uri;

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
for k, v in pairs(h) do
  ngx.header[k] = v;
end
if res1.status==ngx.HTTP_MOVED_PERMANENTLY or res1.status==ngx.HTTP_MOVED_TEMPORARILY then
  ngx.exit(res1.status);
end
ngx.say(res1.body);
--ngx.exit(res1.status);
return;

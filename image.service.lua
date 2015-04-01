--[[
	image process service
]]--


--[[
function explode(szFullString, szSeparator)
	local nFindStartIndex = 1
	local nSplitIndex = 1
	local nSplitArray = {}
	while true do
		local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
		if not nFindLastIndex then
			nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
			break
		end
			nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
			nFindStartIndex = nFindLastIndex + string.len(szSeparator)
			nSplitIndex = nSplitIndex + 1
	end
	return nSplitArray
end
--]]
local function explode(_str, seperator)
	local pos, arr = 0, {}
		for st, sp in function() return string.find( _str, seperator, pos, true ) end do
			table.insert( arr, string.sub( _str, pos, st-1 ) )
			pos = sp + 1
		end
		table.insert( arr, string.sub( _str, pos ) )
	return arr
end

local function trim(_str)
	return (string.gsub(_str, "^%s*(.-)%s*$", "%1"))
end

local function empty(_str)
	if (string.len(_str) < 1) then
		return true;
	end
	return false;
end

local args = {}
local file_args = {}
local is_have_file_param = false


local request_args = ngx.req.get_uri_args()

-- purge the uri
local new_uri = '';
local str_new_uri = '';
local request_uri_seg = explode(ngx.var.request_uri, '/');
for i,v in ipairs(request_uri_seg) do
	if empty(v) ~= true then
		if empty(new_uri) then
			new_uri = v;
		else
			new_uri = new_uri .. '/' .. v;
		end
	end
end
str_new_uri = new_uri;

-- Todo:
-- 	1.add the support of resource directory
--	2.add the config of bucket
new_uri = explode(new_uri, '/');
local bucket = table.remove(new_uri, 1);
local resource = table.remove(new_uri, 1);

-- Todo:
--	1.add the access control
if bucket ~= 'test' then
	ngx.say("Unknown Bucket");
	-- Todo: output 403 header
	ngx.exit(403);
end


local image_root = '';
-- Todo: Check Filename From URI
local destImg = image_root .. '/' .. resource;

local tmpPath = '/tmp';
local resty_sha1 = require "resty.sha1";
local sha1 = resty_sha1:new();
local ok = sha1:update(str_new_uri);
if not ok then
	-- Todo: change To Write Log
	ngx.say("Internal Error: xxx");
	ngx.exit(500);
    return
end
-- binary digest
local digest = sha1:final();
local str = require "resty.string"
-- output: "sha1: b7e23ec29af22b0b4e41da31e868d57226121c84"
local sha1_digest = str.to_hex(digest);
local tmpImg = tmpPath .. '/image_service_' .. sha1_digest;

local headers = ngx.req.get_headers();
local request_method = ngx.var.request_method;
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


local body = ngx.req.read_body();
if string.sub(headers["content-Type"],1,20) == "multipart/form-data;" then
	content_type = headers["content-type"];
	
	-- HTTP Request Body, not usually string
	body_data = ngx.req.get_body_data();

	-- read from temporary file
	if not body_data then
		local datafile = ngx.req.get_body_file();
		if not datafile then
			-- Todo: change To Write Log
			error_code = 1;
			error_msg = "no request body found";
		else
			local fh, err = io.open(datafile, "r");
			if not fh then
				-- Todo: change To Write Log
				error_code = 2;
				error_msg = "failed to open " .. tostring(datafile) .. "for reading: " .. tostring(err);
			else
				fh:seek("set");
				body_data = fh:read("*a");
				fh:close();
				-- Todo: change To Write Log
				if body_data == "" then
					error_code = 3;
					error_msg = "request body is empty";
				end
			end
		end
	end

	-- get The Request Body Data
	local new_body_data = {};
	if not error_code then
		local boundary = "--" .. string.sub(headers["content-type"], 31);
		local body_data_table = explode(tostring(body_data), boundary);
		local first_string = table.remove(body_data_table, 1);
		local last_string = table.remove(body_data_table);
		last_string = trim(last_string);
		for i,v in ipairs(body_data_table) do
			v = trim(v);
			local start_pos, end_pos, capture, capture2 = string.find(v,'Content%-Disposition: form%-data; name="(.+)"; filename="([.%w]*)"');
			-- ordinary param
			if not start_pos then
				local t = explode(v, "\r\n\r\n");
				local temp_param_name = string.sub(t[1], 41, -2);
				local temp_param_value = string.sub(t[2], 1, -3);
				args[temp_param_name] = temp_param_value;
			else
				-- file Type Param, capture is the param name, capture2 is the file name
				file_args[capture] = capture2
				v = explode(v, "\r\n\r\n");
				v = v[2];
				table.insert(new_body_data, v);
			end
		end

		body_data = table.concat(new_body_data);
	end

	-- save the temporary file
	file=io.open(tmpImg,"w");
	file:write(body_data);
	file:close();

	-- convert the image
	local command = "gm convert -flip ".. tmpImg .." " .. destImg;
    os.execute(command);
	os.remove(tmpImg);

	ngx.say("success!");
	ngx.exit(200);
end

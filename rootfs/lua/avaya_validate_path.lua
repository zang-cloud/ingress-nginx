
local _M = {}

-- alternatively: local lrucache = require "resty.lrucache.pureffi"
local lrucache = require "resty.lrucache"
local cache_ttl_seconds = 3600 -- an hour

-- we need to initialize the cache on the lua module level so that
-- it can be shared by all the requests served by each nginx worker process:
local c = lrucache.new(100000)  -- allow up to 100k items in the cache
if not c then
    return error("failed to create the cache: " .. (err or "unknown"))
end

local forbidden_access_message = 'account service-type not allowed to access the requested path'


function _M.go()
    local is_authorized = c:get(ngx.var.request_uri)
    -- is_authorized will be nil if it's not found in cache
    if is_authorized then
        return
    elseif is_authorized == false then
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.say(forbidden_access_message)
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return
    end

    res = ngx.location.capture('/v1/blocked-paths/validate?path=' .. ngx.var.request_uri, {share_all_vars = true, method = ngx.HTTP_GET})

    if res.status == ngx.HTTP_FORBIDDEN then
      c:set(ngx.var.request_uri, false, cache_ttl_seconds)
      ngx.status = res.status
      ngx.say(forbidden_access_message)
      ngx.exit(res.status)
    elseif res.status == ngx.HTTP_OK then
      c:set(ngx.var.request_uri, true, cache_ttl_seconds)
    else
      ngx.log(ngx.WARN, 'failed to validate path ' .. ngx.var.request_uri .. ' response code ' .. res.status)
    end
end

return _M

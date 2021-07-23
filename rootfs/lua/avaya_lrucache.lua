
local _M = {}

-- alternatively: local lrucache = require "resty.lrucache.pureffi"
local lrucache = require "resty.lrucache"
local cache_ttl_seconds = 300 -- five minutes

-- we need to initialize the cache on the lua module level so that
-- it can be shared by all the requests served by each nginx worker process:
local c = lrucache.new(20000)  -- allow up to 20k items in the cache
if not c then
    return error("failed to create the cache: " .. (err or "unknown"))
end


function _M.go()
    local is_authorized = c:get(ngx.var.request_uri)
    -- is_authorized will be nil if it's not found in cache
    if is_authorized then
        return
    elseif is_authorized == false then
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.say("cached false")
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
        return
    end

    res = ngx.location.capture('/validate-path?path=' .. ngx.var.request_uri, {share_all_vars = true, method = ngx.HTTP_GET})
    ngx.log(ngx.ERR, "heron-test resStatus " .. res.status)

    if res.status == ngx.HTTP_UNAUTHORIZED then
      c:set(ngx.var.request_uri, false, cache_ttl_seconds)
      ngx.status = ngx.HTTP_UNAUTHORIZED
      ngx.say(ngx.var.request_uri)
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
    else
      c:set(ngx.var.request_uri, true, cache_ttl_seconds)
    end
end

return _M
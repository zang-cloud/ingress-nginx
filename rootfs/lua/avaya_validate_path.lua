
local _M = {}

-- alternatively: local lrucache = require "resty.lrucache.pureffi"
local lrucache = require "resty.lrucache"
local cache_ttl_seconds = 300 -- five minutes

-- we need to initialize the cache on the lua module level so that
-- it can be shared by all the requests served by each nginx worker process:
local c = lrucache.new(10000)  -- allow up to 10k items in the cache
if not c then
    return error("failed to create the cache: " .. (err or "unknown"))
end


function _M.go()
    local is_authorized = c:get(ngx.var.request_uri)
    -- is_authorized will be nil if it's not found in cache
    if is_authorized then
        return
    elseif is_authorized == false then
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.say('') -- return an empty response instead of nginx default 403 HTMl response
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return
    end

    res = ngx.location.capture('/v1/blocked-paths/validate?path=' .. ngx.var.request_uri, {share_all_vars = true, method = ngx.HTTP_GET})

    if res.status ~= ngx.HTTP_OK then
      ngx.header.content_type = 'application/json';
      if res.status == ngx.HTTP_FORBIDDEN then
        c:set(ngx.var.request_uri, false, cache_ttl_seconds)
      end
      ngx.status = res.status
      ngx.say(res.body)
      ngx.exit(res.status)
    else
      c:set(ngx.var.request_uri, true, cache_ttl_seconds)
    end
end

return _M

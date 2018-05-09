local AuthsCache = require 'apicast.policy.3scale_batcher.auths_cache'
local Usage = require 'apicast.usage'
local lrucache =require 'resty.lrucache'

local storage
local cache
local usage

local service_id = 's1'
local auth_status = 200

describe('Auths cache', function()
  before_each(function()
    storage = lrucache.new(100)
    cache = AuthsCache.new(storage)

    usage = Usage.new()
    usage:add('m1', 1)
  end)

  it('caches auth with user key', function()
    local user_key = { user_key = 'uk' }

    cache:set(service_id, user_key, usage, auth_status)

    local cached = cache:get(service_id, user_key, usage)
    assert.equals(auth_status, cached.status)
  end)

  it('caches auth with app id + app key', function()
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }

    cache:set(service_id, app_id_and_key, usage, auth_status)

    local cached = cache:get(service_id, app_id_and_key, usage)
    assert.equals(auth_status, cached.status)
  end)

  it('caches auth with access token', function()
    local access_token = { access_token = 'a_token' }

    cache:set(service_id, access_token, usage, auth_status)

    local cached = cache:get(service_id, access_token, usage)
    assert.equals(auth_status, cached.status)
  end)

  it('caches auths with same usages but different order in the same key', function()
    local usage_order_1 = Usage.new()
    usage_order_1:add('m1', 1)
    usage_order_1:add('m2', 1)

    local usage_order_2 = Usage.new()
    usage_order_2:add('m2', 1)
    usage_order_2:add('m1', 1)

    local user_key = { user_key = 'uk' }

    cache:set(service_id, user_key, usage_order_1, auth_status)

    local cached = cache:get(service_id, user_key, usage_order_2)
    assert.equals(auth_status, cached.status)
  end)

  it('caches a rejection reason when given', function()
    local rejection_reason = 'limits_exceeded'
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }
    local not_authorized_status = 409

    cache:set(service_id, app_id_and_key, usage, not_authorized_status, rejection_reason)

    local cached = cache:get(service_id, app_id_and_key, usage)
    assert.equals(not_authorized_status, cached.status)
    assert.equals(rejection_reason, cached.rejection_reason)
  end)

  it('returns nil when something is not cached', function()
    local user_key = { user_key = 'uk' }

    assert.is_nil(cache:get(service_id, user_key, usage))
  end)
end)

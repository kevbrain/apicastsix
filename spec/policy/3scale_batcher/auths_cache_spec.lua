local AuthsCache = require 'apicast.policy.3scale_batcher.auths_cache'
local Usage = require 'apicast.usage'
local Transaction = require 'apicast.policy.3scale_batcher.transaction'
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
    local transaction = Transaction.new(service_id, user_key, usage)

    cache:set(transaction, auth_status)

    local cached = cache:get(transaction)
    assert.equals(auth_status, cached.status)
  end)

  it('caches auth with app id + app key', function()
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }
    local transaction = Transaction.new(service_id, app_id_and_key, usage)

    cache:set(transaction, auth_status)

    local cached = cache:get(transaction)
    assert.equals(auth_status, cached.status)
  end)

  it('caches auth with access token', function()
    local access_token = { access_token = 'a_token' }
    local transaction = Transaction.new(service_id, access_token, usage)

    cache:set(transaction, auth_status)

    local cached = cache:get(transaction)
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

    local transaction_with_order_1 = Transaction.new(service_id, user_key, usage_order_1)
    local transaction_with_order_2 = Transaction.new(service_id, user_key, usage_order_2)

    cache:set(transaction_with_order_1, auth_status)

    local cached = cache:get(transaction_with_order_2)
    assert.equals(auth_status, cached.status)
  end)

  it('caches a rejection reason when given', function()
    local rejection_reason = 'limits_exceeded'
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }
    local transaction = Transaction.new(service_id, app_id_and_key, usage)
    local not_authorized_status = 409

    cache:set(transaction, not_authorized_status, rejection_reason)

    local cached = cache:get(transaction)
    assert.equals(not_authorized_status, cached.status)
    assert.equals(rejection_reason, cached.rejection_reason)
  end)

  it('returns nil when something is not cached', function()
    local user_key = { user_key = 'uk' }
    local transaction = Transaction.new(service_id, user_key, usage)

    assert.is_nil(cache:get(transaction))
  end)
end)

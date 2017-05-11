local _M = require 'examples.custom-module.blacklist'
local apicast = require 'apicast'

describe('blacklist', function()
  it('returns new module instance', function()
    local blacklist = _M.new()

    assert.table(blacklist)
    assert.equal(_M.balancer, blacklist.balancer)
    assert.equal(_M.init, blacklist.init)
  end)

  it('has all apicast methods', function()
    local blacklist = _M.new()

    assert['function'](blacklist.init)

    for _,fun in ipairs{'init_worker', 'rewrite', 'post_action', 'access', 'log'} do
      assert.equal(apicast[fun], blacklist[fun], fun .. " is not inherited from apicast")
    end

    assert['function'](blacklist.balancer)
  end)
end)

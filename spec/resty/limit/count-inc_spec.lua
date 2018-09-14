local _M = require 'resty.limit.count-inc'

local shdict_mt = {
  __index = {
    get = function(t, k) return rawget(t, k) end,
    set = function(t, k, v) rawset(t, k , v); return true end,
    incr = function(t, key, inc, init, _)
      local value = t:get(key) or init
      if not value then return nil, 'not found' end

      t:set(key, value + inc)
      return t:get(key)
    end,
  }
}
local function shdict()
  return setmetatable({ }, shdict_mt)
end

describe('resty.limit.count-inc', function()

  before_each(function()
    ngx.shared.limiter = mock(shdict(), true)
  end)

  describe('.new', function()
    describe('using correct shdict', function()
      it('returns limiter', function()
        local lim = _M.new('limiter', 1, 1)
        assert.same(1, lim.limit)
        assert.same(1, lim.window)
      end)
    end)

    describe('using incorrect shdict', function()
      it('returns error', function()
        local _, err = _M.new('incorrect', 1, 1)
        assert.same('shared dict not found', err)
      end)
    end)
  end)

  describe('.incoming', function()
    local lim

    before_each(function()
      lim = _M.new('limiter', 1, 1)
    end)

    describe('when commit is true', function()
      describe('if count is less than limit', function()
        it('returns zero and remaining', function()
          local delay, err = lim:incoming('tmp', true)
          assert.same(0, delay)
          assert.same(0, err)
        end)

        describe('and incr method fails', function()
          it('returns error', function()
            ngx.shared.limiter.incr = function()
              return nil, 'something'
            end
            local delay, err = lim:incoming('tmp', true)
            assert.is_nil(delay)
            assert.same('something', err)
          end)
        end)
      end)

      describe('if count is greater than limit', function()
        it('return rejected', function()
          lim:incoming('tmp', true)
          local delay, err = lim:incoming('tmp', true)
          assert.is_nil(delay)
          assert.same('rejected', err)
        end)

        describe('and incr method fails', function()
          it('returns error', function()
            ngx.shared.limiter.incr = function(t, key, inc, init, _)
              local value = t:get(key) or init
              if not value then return nil, 'not found' end
              if inc == -1 then return nil, 'something' end
              t:set(key, value + inc)
              return t:get(key)
            end
            lim:incoming('tmp', true)
            local delay, err = lim:incoming('tmp', true)
            assert.is_nil(delay)
            assert.same('something', err)
          end)
        end)
      end)
    end)

    describe('when commit is false', function()
      describe('if count is less than limit', function()
        it('returns zero and remaining', function()
          local delay, err = lim:incoming('tmp', false)
          assert.same(0, delay)
          assert.same(0, err)
        end)
      end)

      describe('if count is greater than limit', function()
        it('return rejected', function()
          lim:incoming('tmp', true)
          local delay, err = lim:incoming('tmp', false)
          assert.is_nil(delay)
          assert.same('rejected', err)
        end)
      end)
    end)

  end)

  describe('.uncommit', function()
    local lim

    before_each(function()
      lim = _M.new('limiter', 1, 1)
    end)

    describe('when incr method succeeds', function()
      it('returns remaining', function()
        lim:incoming('tmp', true)
        local delay = lim:uncommit('tmp')
        assert.same(1, delay)
      end)
    end)

    describe('when incr method fails', function()
      describe('if key is not found', function()
        it('returns remaining', function()
          local delay = lim:uncommit('tmp')
          assert.same(1, delay)
        end)
      end)

      it('returns error', function()
        lim:incoming('tmp', true)
        ngx.shared.limiter.incr = function()
          return nil, 'something'
        end
        local delay, err = lim:uncommit('tmp')
        assert.is_nil(delay)
        assert.same('something', err)
      end)
    end)
  end)

end)

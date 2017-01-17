local _M = require 'resty.env'

describe('env', function()
  local env
  before_each(function() env = _M.env end)
  after_each(function() _M.env = env end)

  describe('.get', function()

    local path = os.getenv("PATH")

    it('returns contents of the ENV variable', function()
      assert.equal(path, _M.get('PATH'))
    end)

    it('caches the result', function()
      _M.get('PATH')

      assert.equal(path, _M.env.PATH)
    end)

    it('reads from the cache first', function()
      _M.env = { ['SOME_MISSING_ENV_VAR'] = 'somevalue' }

      assert.equal('somevalue', _M.get("SOME_MISSING_ENV_VAR"))
    end)
  end)

  describe('.set', function()
    it('saves value to the cache', function()
      _M.set('SOME_MISSING_KEY', 'val')

      assert.equal('val', _M.env.SOME_MISSING_KEY)
    end)
  end)
end)

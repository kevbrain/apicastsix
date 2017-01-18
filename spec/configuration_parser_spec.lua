local _M = require 'configuration_parser'
local configuration = require 'configuration'
local cjson = require 'cjson'

describe('Configuration Parser', function()
  describe('.parse', function()
    it('returns new configuration object', function()
      assert.same(configuration.new({}), _M.parse('{}', cjson))
    end)

    it('works with table', function()
      assert.same(configuration.new({}), _M.parse({}))
    end)
  end)

  describe('.decode', function()
    it('ignores empty string', function()
      assert.same(nil, _M.decode(''))
    end)
  end)

  describe('.encode', function()
    it('encodes to json by default', function()
      local t = { a = 1, b = 2 }
      assert.same('{"a":1,"b":2}', _M.encode(t))
    end)

    it('does not do double encoding', function()
      local str = '{"a":1,"b":2}'
      assert.same(str, _M.encode(str))
    end)

    it('encodes nil to null', function()
      assert.same('null', _M.encode(nil))
    end)
  end)
end)

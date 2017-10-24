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
end)

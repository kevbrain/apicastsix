local _M = require 'apicast.configuration_parser'
local configuration = require 'apicast.configuration'
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
      assert.is_nil(_M.decode(''))
    end)

    it('decodes nil as nil', function()
      assert.is_nil(_M.decode(nil))
    end)

    it('when given a table returns the same table', function()
      local t = { a = 1, b = 2 }
      assert.same(t, _M.decode(t))
    end)

    describe('when a decoder is not specified', function()
      it('uses cjson', function()
        local contents = '{"a":1,"b":2}'
        assert.same(cjson.decode(contents), _M.decode(contents))
      end)

      it('returns nil and an error when cjson fails to decode', function()
        local contents = '{"a:1}' --malformed
        local res, err = _M.decode(contents)
        assert.is_nil(res)
        assert.not_nil(err)
      end)
    end)

    describe('when a decoder is specified', function()
      local custom_decoder = {
        decode = function(contents)
          return (contents == 'err' and error('oh no')) or contents
        end
      }

      it('uses the given decoder instead of cjson', function()
        assert.equal(custom_decoder.decode('a'),
                     _M.decode('a', custom_decoder))
      end)

      it('returns nil and an error when the given decoder fails', function()
        local res, err = _M.decode('err', custom_decoder)
        assert.is_nil(res)
        assert.not_nil(err)
      end)
    end)
  end)
end)

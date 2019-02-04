local _M = require('apicast.cli.template')

describe('Liquid Template', function ()

  describe('default filter', function()
    it('overrides nil values', function()
      local str = _M:new():interpret([[{{ nothing | default: "foo" }}]])

      assert.equal(str, 'foo')
    end)

    it('overrides false values', function()
      local str = _M:new():interpret([[{{ false | default: "foo" }}]])

      assert.equal(str, 'false')
    end)
  end)

end)

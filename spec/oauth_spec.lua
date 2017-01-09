local oauth = require 'oauth'

describe('OAuth', function()
  describe('.call', function()
    it('returns function matching the route', function()
      assert.equals('function', type(oauth.call('GET', '/authorize')))
    end)
  end)
end)

local oauth = require 'oauth'

describe('OAuth', function()
  describe('.call', function()
    it('returns function matching the route', function()
      assert.equals('function', type(oauth.call('GET', '/authorize')))
      assert.equals('function', type(oauth.call('POST', '/authorize')))
      assert.equals('function', type(oauth.call('POST', '/oauth/token')))
      assert.equals('function', type(oauth.call('GET', '/callback')))
      assert.equals('function', type(oauth.call('POST', '/callback')))
    end)
  end)
end)

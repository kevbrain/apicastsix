local oauth = require 'oauth'
local keycloak = require 'oauth.keycloak'
local apicast_oauth = require 'oauth.apicast_oauth'

describe('OAuth', function()

  describe('.new', function()
    it('returns keycloak instance when keycloak configured', function()
      local configuration = { keycloak = {} }

      stub(keycloak, 'new')
      oauth.new(configuration)
      assert.spy(keycloak.new).was.called_with(configuration.keycloak)
    end)

    it('returns apicast_oauth instance when keycloak not configured', function()
      local configuration = {}

      stub(apicast_oauth, 'new')
      oauth.new(configuration)
      assert.spy(apicast_oauth.new).was.called()
    end)
  end)

  describe('.call', function()
    it('returns function matching the route', function()
      local configuration = {}
      local o = oauth.new(configuration)
      assert.equals('function', type(oauth.call(o, {}, 'GET', '/authorize')))
      assert.equals('function', type(oauth.call(o, {}, 'POST', '/authorize')))
      assert.equals('function', type(oauth.call(o, {}, 'POST', '/oauth/token')))
      assert.equals('function', type(oauth.call(o, {}, 'GET', '/callback')))
      assert.equals('function', type(oauth.call(o, {}, 'POST', '/callback')))
    end)
  end)
end)

local oauth = require 'apicast.oauth'

describe('OAuth', function()
  describe('.oidc', function()
    it(function() assert.equal(require('apicast.oauth.oidc'), oauth.oidc) end)
  end)

  describe('.apicast', function()
    it(function() assert.equal(require('apicast.oauth.apicast_oauth'), oauth.apicast) end)
  end)

end)

local _M = require 'resty.http_ng.response'
local request = require 'resty.http_ng.request'

describe('http_ng response', function()

  describe('error', function()

    local req = request.new{ method = 'GET', url = 'http://example.com' }

    it('has the request', function()
      local error = _M.error(req, 'failed')

      assert.equal(req, error.request)
    end)


    it('has the message', function()
      local error = _M.error(req, 'error message')

      assert.equal('error message', error.error)
    end)
  end)
end)

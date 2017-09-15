local backend = require 'resty.http_ng.backend.resty'

describe('resty backend', function()

  describe('GET method #network', function()
    local method = 'GET'

    it('accesses the url', function()
      local response, err = backend:send{method = method, url = 'http://example.com/'}
      assert.falsy(err)
      assert.falsy(response.error)
      assert.truthy(response.ok)
      assert.truthy(response.request)
    end)

    it('works with ssl', function()
      local response, err = backend:send{
        method = method, url = 'https://google.com/',
        -- This is needed because of https://groups.google.com/forum/#!topic/openresty-en/SuqORBK9ys0
        -- So far OpenResty can't use system certificated on demand.
        options = { ssl = { verify = false } }
      }
      assert.falsy(err)
      assert.falsy(response.error)
      assert.truthy(response.ok)
      assert.truthy(response.request)
      assert(response.headers.location:match('^https://'))
    end)

    it('returns error', function()
      local req = { method = method, url = 'http://0.0.0.0:0/' }
      local response, err = backend:send(req)

      assert.falsy(err)
      assert.truthy(response.error)
      assert.falsy(response.ok)
      assert.same(req, response.request)
    end)
  end)
end)

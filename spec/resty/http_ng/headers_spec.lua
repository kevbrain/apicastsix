local _M = require 'resty.http_ng.headers'

describe('headers', function()
  describe('normalization', function()
    it('normalizes Cache-Control', function()
      local headers = _M.new{ ['Cache-Control'] = 'public' }
      assert.equal('public', headers.cache_control)
    end)

    it('normalizes ETag', function()
      local headers = _M.new{ ['ETag'] = 'foo' }
      assert.equal('foo', headers.etag)
    end)

    it('works with normal access', function()
      local headers = _M.new{ ['ETag'] = 'foo' }
      assert.equal('foo', headers['ETag'])
    end)
  end)

  describe('value serialization', function()
    it('concatenates arrays', function()
      local headers = _M.new{ ['Cache-Control'] = { 'public', 'max-age=1' } }


      assert.equal('public, max-age=1', tostring(headers.cache_control))
    end)

    it('concatenates hashes', function()
      local headers = _M.new{ ['Cache-Control'] = { public = true, ['must-revalidate'] = true } }

      assert.equal('must-revalidate, public', tostring(headers.cache_control))
    end)
  end)
end)

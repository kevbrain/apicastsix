local util = require 'util'

describe('util',function()
  describe('system', function()
    local system = util.system

    it('returns output', function()
      local output = system('echo true-output')
      assert.equal('true-output\n', output)
    end)

    it('returns error', function()
      local success, err, code = system('sh missing-file')

      assert.falsy(success)
      assert.truthy(err:find('sh:'))
      assert.truthy(err:find('missing%-file'))
      assert.truthy(code > 0)
    end)
  end)
end)

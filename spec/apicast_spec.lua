local apicast = require 'apicast'

describe('APIcast module', function()

  it('has a name', function()
    assert.truthy(apicast._NAME)
  end)

  it('has a version', function()
    assert.truthy(apicast._VERSION)
  end)
end)

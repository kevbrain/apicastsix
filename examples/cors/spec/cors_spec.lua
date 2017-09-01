local _M = require 'cors'

describe('cors', function()
	it('is', function()
		assert.match('CORS', _M._NAME)
	end)
end)

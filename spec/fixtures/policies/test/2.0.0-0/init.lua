local Policy = require('apicast.policy').new('Test', '1.0.0-0')

Policy.dependency = require('dependency')

return Policy

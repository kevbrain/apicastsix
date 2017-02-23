#!/usr/bin/env resty -I apicast/src

local inspect = require 'inspect'

local resty_resolver = require 'resty.resolver'

local r = resty_resolver:instance()

local host = arg[1]

if not host then
  print('missing host')
  print('usage: ' .. arg[0] .. ' example.com')
  os.exit(1)
end

local servers, err = r:get_servers(host)

if err then
  print('error: ', err)
  print(inspect(r))
  os.exit(1)
end

print(inspect(servers))

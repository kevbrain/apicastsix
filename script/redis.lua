#!/usr/bin/env resty -I apicast/src

local cmd = arg[1]
local args = {}

for i=2, #arg do
  table.insert(args, arg[i])
end

if not cmd then
  print('missing command')
  print('usage: ' .. arg[0] .. ' cmd [arg [arg ...]]')
  os.exit(1)
end

local inspect = require 'inspect'
local ts = require 'threescale_utils'

local red, err = ts.connect_redis()

if not red and err then
  print('could not connect to redis: ', err)
  os.exit(1)
end

local fn = red[cmd]
local res, err = fn(red, unpack(args))

if err then
  print('error: ', err)
  print(inspect(r))
  os.exit(1)
end

print(inspect(res))

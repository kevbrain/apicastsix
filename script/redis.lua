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

local red, connerr = ts.connect_redis()

if not red and connerr then
  print('could not connect to redis: ', connerr)
  os.exit(1)
end

local fn = red[cmd]
local res, err = fn(red, unpack(args))

if res then
  print(inspect(res))
end

if err then
  print('error: ', err)
  os.exit(1)
end

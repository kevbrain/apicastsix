
local ffi = require 'ffi'

local CLOCK = {
  REALTIME                  = 0,
  MONOTONIC                 = 1,
  PROCESS_CPUTIME_ID        = 2,
  THREAD_CPUTIME_ID         = 3,
  MONOTONIC_RAW             = 4,
  REALTIME_COARSE           = 5,
  MONOTONIC_COARSE          = 6,
}

local function time_ns(clock)
  local ts = ffi.new("struct timespec[1]")
  assert(ffi.C.clock_gettime(clock or CLOCK.MONOTONIC_RAW, ts) == 0,
    "clock_gettime() failed: "..ffi.errno())
  return tonumber(ts[0].tv_sec * 1e9 + ts[0].tv_nsec)
end

local monotime = require('busted.core')().monotime

require('benchmark.ips')(function(b)
  b.time = 5
  b.warmup = 2

  b:report('ffi', function() return time_ns() end)
  b:report('syscall', function() return monotime() end)

  b:compare()
end)

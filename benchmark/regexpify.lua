local re_gsub = ngx.re.gsub

require('resty.core')
require('benchmark.ips')(function(b)
  b.time = 5
  b.warmup = 2

  local gsub = string.gsub

  local ffi_re_gsub = ngx.re.gsub

  local transforms = {
    { '?.*', '' },
    { "{.-}", [[([\w-.~%%!$&'()*+,;=@:]+)]] },
    { "%.", [[\.]] },
  }

  local function loop(pattern)
    for i=1, #transforms do
      pattern = gsub(pattern, transforms[i][1], transforms[i][2])
    end
    return pattern
  end

  local function closure(pattern)
    pattern = gsub(pattern, '?.*', '')
    pattern = gsub(pattern, "{.-}", [[([\w-.~%%!$&'()*+,;=@:]+)]])
    pattern = gsub(pattern, "%.", "\\.")

    return pattern
  end

  local function global(pattern)
    -- as per the RFC: https://tools.ietf.org/html/rfc3986#section-3.3
    local wildcard_regex = [[([\w-.~%%!$&'()*+,;=@:]+)]] -- using long Lua brackets [[...]], escaping `%`
    return pattern:gsub('?.*', ''):gsub("{.-}", wildcard_regex):gsub("%.", "\\.")
  end

  local function pcre(pattern)
    pattern = re_gsub(pattern, [[\?.*]], '')
    pattern = re_gsub(pattern, [[\{.+?\}]], [[([\w-.~%!$$&'()*+,;=@:]+)]])
    pattern = re_gsub(pattern, [[\.]], [[\.]])

    return pattern
  end

  local function pcre_jit(pattern)
    pattern = re_gsub(pattern, [[\?.*]], '', 'oj')
    pattern = re_gsub(pattern, [[\{.+?\}]], [[([\w-.~%!$$&'()*+,;=@:]+)]], 'oj')
    pattern = re_gsub(pattern, [[\.]], [[\.]], 'oj')

    return pattern
  end

  local function ffi_pcre(pattern)
    pattern = ffi_re_gsub(pattern, [[\?.*]], '')
    pattern = ffi_re_gsub(pattern, [[\{.+?\}]], [[([\w-.~%!$$&'()*+,;=@:]+)]])
    pattern = ffi_re_gsub(pattern, [[\.]], [[\.]])

    return pattern
  end

  local function ffi_pcre_jit(pattern)
    pattern = ffi_re_gsub(pattern, [[\?.*]], '', 'oj')
    pattern = ffi_re_gsub(pattern, [[\{.+?\}]], [[([\w-.~%!$$&'()*+,;=@:]+)]], 'oj')
    pattern = ffi_re_gsub(pattern, [[\.]], [[\.]], 'oj')

    return pattern
  end

  local str = '/tfgoodosod/{foo}/sdsd?asdasdd'

  print('loop:   ' , loop(str))
  print('closure:' , closure(str))
  print('global: ' , global(str))
  print('pcre:   ' , pcre(str))

  b:report('loop', function() return loop(str) end)
  b:report('gsub', function() return closure(str) end)
  b:report('string.gsub', function() return global(str) end)
  b:report('re.gsub', function() return pcre(str) end)
  b:report('re.gsub jit', function() return pcre_jit(str) end)

  b:report('ffi re.gsub', function() return ffi_pcre(str) end)
  b:report('ffi re.gsub jit', function() return ffi_pcre_jit(str) end)

  b:compare()
end)

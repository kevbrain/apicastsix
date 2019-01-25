local ffi = require('ffi')
local base = require('resty.openssl.base')

ffi.cdef([[
const EVP_MD *EVP_sha1(void);
const EVP_MD *EVP_sha256(void);
const EVP_MD *EVP_sha512(void);
const EVP_MD *EVP_get_digestbyname(const char *name);
]])

local C = ffi.C
local assert = assert
local tocdata = base.tocdata

local _M = { }

local function find(name)
  local md = C.EVP_get_digestbyname(name)

  if not md then
    return nil, 'not found'
  end

  return md
end

local mt = {
  __index = _M,

  __new = function(ct, md)
    return ffi.new(ct, assert(md))
  end,

  __len = function(self)
    return tocdata(self).md_size
  end,
}

local EVP_MD = ffi.metatype('struct { const EVP_MD *cdata; }', mt)

function _M.new(name)
  local md, err = find(name)

  if not md then return nil, err end

  return EVP_MD(md)
end

function _M.sha1()
  return _M.new('SHA1')
end

function _M.sha256()
  return _M.new('SHA256')
end

function _M.sha512()
  return _M.new('SHA512')
end

return _M

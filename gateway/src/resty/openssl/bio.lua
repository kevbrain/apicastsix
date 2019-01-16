local base = require('resty.openssl.base')
local ffi = require('ffi')

ffi.cdef([[
  // https://www.openssl.org/docs/manmaster/man3/BIO_write.html
  BIO_METHOD *BIO_s_mem(void);
  BIO * BIO_new(BIO_METHOD *type);
  void BIO_vfree(BIO *a);
  int BIO_read(BIO *b, void *data, int len);
  int BIO_write(BIO *b, const void *data, int dlen);

  size_t BIO_ctrl_pending(BIO *b);
]])
local C = ffi.C
local ffi_assert = base.ffi_assert
local str_len = string.len
local assert = assert

local _M = {

}

local mt = {
  __index = _M,
  __new = function(ct, bio_method)
    local bio = ffi_assert(C.BIO_new(bio_method))

    return ffi.new(ct, bio)
  end,
  __gc = function(self)
    C.BIO_vfree(self.cdata)
  end,
}

-- no changes to the metamethods possible from this point
local BIO = ffi.metatype('struct { BIO *cdata; }', mt)

local bio_mem = C.BIO_s_mem()

function _M:read()
  local bio = self.cdata
  --  BIO_ctrl_pending() return the amount of pending data.
  local len = C.BIO_ctrl_pending(bio)
  local buf = ffi.new("char[?]", len)
  ffi_assert(C.BIO_read(bio, buf, len) >= 0)
  return ffi.string(buf, len)
end

function _M:write(str)
  local len = str_len(assert(str, 'expected string'))

  return ffi_assert(C.BIO_write(self.cdata, str, len))
end

function _M.new()
  return BIO(bio_mem)
end

return _M

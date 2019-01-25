local ffi = require('ffi')

ffi.cdef([[
  typedef long time_t;

  // https://github.com/openssl/openssl/blob/4ace4ccda2934d2628c3d63d41e79abe041621a7/include/openssl/ossl_typ.h
  typedef struct x509_store_st X509_STORE;
  typedef struct x509_st X509;
  typedef struct X509_crl_st X509_CRL;
  typedef struct X509_name_st X509_NAME;
  typedef struct bio_st BIO;
  typedef struct bio_method_st BIO_METHOD;
  typedef struct X509_VERIFY_PARAM_st X509_VERIFY_PARAM;
  typedef struct stack_st OPENSSL_STACK;
  typedef struct evp_md_st {
    int type;
    int pkey_type;
    int md_size;
  } EVP_MD;

  unsigned long ERR_get_error(void);
  const char *ERR_reason_error_string(unsigned long e);

  void ERR_clear_error(void);
]])

local C = ffi.C
local _M = { }

local error = error

local function openssl_error()
  local code, reason

  while true do
    --[[
    https://www.openssl.org/docs/man1.1.0/crypto/ERR_get_error.html

      ERR_get_error() returns the earliest error code
      from the thread's error queue and removes the entry.
      This function can be called repeatedly
      until there are no more error codes to return.
    ]]--
    code = C.ERR_get_error()

    if code == 0 then
      break
    else
      reason = C.ERR_reason_error_string(code)
    end
  end

  C.ERR_clear_error()

  if reason then
    return ffi.string(reason)
  end
end

local function ffi_value(ret, expected)
  if ret == nil or ret == -1 or (expected and ret ~= expected) then
    return nil, openssl_error() or 'expected value, got nil'
  end

  return ret
end

local function ffi_assert(ret, expected)
  local value, err = ffi_value(ret, expected)

  if not value then
    error(err, 2)
  end

  return value
end

local function tocdata(obj)
  return obj and obj.cdata or obj
end

_M.ffi_assert = ffi_assert
_M.ffi_value = ffi_value
_M.openssl_error = openssl_error
_M.tocdata = tocdata

return _M

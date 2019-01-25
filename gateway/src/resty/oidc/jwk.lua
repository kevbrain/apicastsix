local ipairs = ipairs

local b64 = require('ngx.base64')
local ffi = require('ffi')
local tab_new = require('resty.core.base').new_tab
local base = require('resty.openssl.base')

ffi.cdef [[
typedef struct bio_st BIO;
typedef struct bio_method_st BIO_METHOD;
BIO_METHOD *BIO_s_mem(void);
BIO * BIO_new(BIO_METHOD *type);
void BIO_vfree(BIO *a);
int BIO_read(BIO *b, void *data, int len);

size_t BIO_ctrl_pending(BIO *b);

typedef struct bignum_st BIGNUM;
typedef void FILE;

BIGNUM *BN_bin2bn(const unsigned char *s, int len, BIGNUM *ret);
BIGNUM *BN_new(void);
void BN_free(BIGNUM *a);

int RSA_set0_key(RSA *r, BIGNUM *n, BIGNUM *e, BIGNUM *d);
RSA * RSA_new(void);

void RSA_free(RSA *rsa);

int PEM_write_RSA_PUBKEY(FILE *fp, RSA *x);
int PEM_write_bio_RSA_PUBKEY(BIO *bp, RSA *x);
]]

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_assert = base.ffi_assert

local _M = { }

_M.jwk_to_pem = { }

local function b64toBN(str)
    local val, err = b64.decode_base64url(str)
    if not val then return nil, err end

    local bn = ffi_assert(C.BN_new())
    ffi_gc(bn, C.BN_free)

    ffi_assert(C.BN_bin2bn(val, #val, bn))

    return bn
end

local function read_BIO(bio)
    --  BIO_ctrl_pending() return the amount of pending data.
    local len = C.BIO_ctrl_pending(bio)
    local buf = ffi.new("char[?]", len)
    ffi_assert(C.BIO_read(bio, buf, len) >= 0)
    return ffi.string(buf, len)
end

local bio_mem = C.BIO_s_mem()

local function new_BIO()
    local bio = ffi_assert(C.BIO_new(bio_mem))

    ffi_gc(bio, C.BIO_vfree)

    return bio
end

local function RSA_to_PEM(rsa)
    local bio = new_BIO()

    ffi_assert(C.PEM_write_bio_RSA_PUBKEY(bio, rsa), 1)

    return read_BIO(bio)
end


local function RSA_new(n, e, d)
    --- https://github.com/sfackler/rust-openssl/blob/2df87cfd5974da887b5cb84c81e249f485bed9f7/openssl/src/rsa.rs#L420-L437
    local rsa = ffi_assert(C.RSA_new())
    ffi_gc(rsa, C.RSA_free)

    --[[
    The n, e and d parameter values can be set by calling RSA_set0_key()
    and passing the new values for n, e and d as parameters to the function.
    The values n and e must be non-NULL the first time this function is called
    on a given RSA object. The value d may be NULL.
    ]]--

    ffi_assert(C.RSA_set0_key(rsa, n, e, d), 1)

    --[[
    Calling this function transfers the memory management of the values
    to the RSA object, and therefore the values that have been passed
    in should not be freed by the caller after this function has been called.
    ]]--
    ffi_gc(n, nil)
    ffi_gc(e, nil)

    return rsa
end

function _M.jwk_to_pem.RSA(jwk)
    local n, e, err

    -- parameter n: Base64 URL encoded string representing the modulus of the RSA Key.
    n, err = b64toBN(jwk.n)
    if err then return nil, err end

    -- parameter e: Base64 URL encoded string representing the public exponent of the RSA Key.
    e, err = b64toBN(jwk.e)
    if err then return nil, err end

    local rsa = RSA_new(n, e)

    -- jwk.rsa = rsa
    jwk.pem = RSA_to_PEM(rsa)

    return jwk
end

function _M.convert_keys(res, ...)
    if not res then return nil, ... end
    local keys = tab_new(0, #res.keys)

    for _,jwk in ipairs(res.keys) do
        keys[jwk.kid] = _M.convert_jwk_to_pem(jwk)
    end

    return keys
end

function _M.convert_jwk_to_pem(jwk)
    local fun = _M.jwk_to_pem[jwk.kty]

    if not fun then
        return nil, 'unsupported kty'
    end

    return fun(jwk)
end

return _M

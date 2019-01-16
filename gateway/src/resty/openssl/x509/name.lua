local base = require('resty.openssl.base')
local BIO = require('resty.openssl.bio')
local ffi = require('ffi')
local bit = require('bit')

ffi.cdef([[
int X509_NAME_print_ex(BIO *out, const X509_NAME *nm, int indent, unsigned long flags);
char * X509_NAME_oneline(const X509_NAME *a, char *buf, int size);
int X509_NAME_print(BIO *bp, const X509_NAME *name, int obase);
]])

local const = {

}

const.XN_FLAG_SEP_MASK = bit.lshift(0xf, 16)

const.XN_FLAG_COMPAT = 0
const.XN_FLAG_SEP_COMMA_PLUS = bit.lshift(1, 16)
const.XN_FLAG_SEP_CPLUS_SPC = bit.lshift(2, 16)
const.XN_FLAG_SEP_SPLUS_SPC = bit.lshift(3, 16)
const.XN_FLAG_SEP_MULTILINE = bit.lshift(4, 16)
const.XN_FLAG_DN_REV = bit.lshift(1, 20)
const.XN_FLAG_FN_MASK = bit.lshift(0x3, 21)
const.XN_FLAG_FN_SN = 0
const.XN_FLAG_FN_LN = bit.lshift(1, 21)
const.XN_FLAG_FN_OID = bit.lshift(2, 21)
const.XN_FLAG_FN_NONE = bit.lshift(3, 21)
const.XN_FLAG_SPC_EQ = bit.lshift(1, 23)
const.XN_FLAG_DUMP_UNKNOWN_FIELDS = bit.lshift(1, 24)
const.XN_FLAG_FN_ALIGN = bit.lshift(1, 25)
const.ASN1_STRFLGS_ESC_2253 = 1
const.ASN1_STRFLGS_ESC_CTRL = 2
const.ASN1_STRFLGS_ESC_MSB = 4
const.ASN1_STRFLGS_ESC_QUOTE = 8
const.CHARTYPE_PRINTABLESTRING = 0x10
const.CHARTYPE_FIRST_ESC_2253 = 0x20
const.CHARTYPE_LAST_ESC_2253 = 0x40
const.ASN1_STRFLGS_UTF8_CONVERT = 0x10
const.ASN1_STRFLGS_IGNORE_TYPE = 0x20
const.ASN1_STRFLGS_SHOW_TYPE = 0x40
const.ASN1_STRFLGS_DUMP_ALL = 0x80
const.ASN1_STRFLGS_DUMP_UNKNOWN = 0x100
const.ASN1_STRFLGS_DUMP_DER = 0x200
const.SN1_STRFLGS_ESC_2254 = 0x400

const.ASN1_STRFLGS_RFC2253 = bit.bor(
    const.ASN1_STRFLGS_ESC_2253,
    const.ASN1_STRFLGS_ESC_CTRL,
    const.ASN1_STRFLGS_ESC_MSB,
    const.ASN1_STRFLGS_UTF8_CONVERT,
    const.ASN1_STRFLGS_DUMP_UNKNOWN,
    const.ASN1_STRFLGS_DUMP_DER
)

const.XN_FLAG_RFC2253 = bit.bor(
    const.ASN1_STRFLGS_RFC2253,
    const.XN_FLAG_SEP_COMMA_PLUS,
    const.XN_FLAG_DN_REV,
    const.XN_FLAG_FN_SN,
    const.XN_FLAG_DUMP_UNKNOWN_FIELDS
)

const.XN_FLAG_ONELINE = bit.bor(
    const.ASN1_STRFLGS_RFC2253,
    const.ASN1_STRFLGS_ESC_QUOTE,
    const.XN_FLAG_SEP_CPLUS_SPC,
    const.XN_FLAG_SPC_EQ,
    const.XN_FLAG_FN_SN
)

const.XN_FLAG_MULTILINE = bit.bor(
    const.ASN1_STRFLGS_ESC_CTRL,
    const.ASN1_STRFLGS_ESC_MSB,
    const.XN_FLAG_SEP_MULTILINE,
    const.XN_FLAG_SPC_EQ,
    const.XN_FLAG_FN_LN,
    const.XN_FLAG_FN_ALIGN
)

local C = ffi.C
local tocdata = base.tocdata
local assert = assert
local _M = {}
local mt = {
  __index = _M,
  __new = ffi.new,
  __tostring = function(self)
    local bio = BIO.new()

    C.X509_NAME_print_ex(tocdata(bio), tocdata(self), 0, const.XN_FLAG_ONELINE)

    return bio:read()
  end
}

local X509_NAME = ffi.metatype('struct { X509_NAME *cdata; }', mt)

function _M.new(name)
  return X509_NAME(assert(name))
end

return _M

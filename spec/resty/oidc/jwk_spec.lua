local cjson = require('cjson')
local jwk = cjson.encode({
    alg = "RS256",
    e = "AQAB",
    kid = "e4pNCHUfUlIPWmHyNHvfglHLVRwJDYlyKP4ayau-dRc",
    kty = "RSA",
    n = "pEP4cp6E7loZGIMXrbWqAVh2wL8h-jZ77J94XKeCO4cRUuQ3XP_k8Ce2WB8aez5hSXwOkXr2S6HKmgnrQhCdX3RWMI-wa0JceU1bCGIjdQeP-ejqP5Gq2RKdgYImc3wvSH6HnHgBOn2OfkLydCdUlgAuSLoSSk4Z_EM--EvvxH_ff1Vp4HAotP0voXEWFwMPm5YFZk79x1oNnFyxOr_fWM4Es9J2p1vPtph7RczEKZ4UKSvjOlQ_E_NNxPP5hLs3hFouuEH_-8tr2tiDgQ66P-EfjmFHrFEvcJ2vis1JtFgHaX9iYmuTPAD4VCY9WRLlZQhEslJOOWbNOjtKTdfYXw",
    use = "sig"
})

local _M = require('resty.oidc.jwk')

describe('JWK', function()
    describe('.convert_jwk_to_pem(jwk)', function()
        local key
        before_each(function() key = cjson.decode(jwk) end)

        it('generates PEM certificate', function()
            assert.equal([[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApEP4cp6E7loZGIMXrbWq
AVh2wL8h+jZ77J94XKeCO4cRUuQ3XP/k8Ce2WB8aez5hSXwOkXr2S6HKmgnrQhCd
X3RWMI+wa0JceU1bCGIjdQeP+ejqP5Gq2RKdgYImc3wvSH6HnHgBOn2OfkLydCdU
lgAuSLoSSk4Z/EM++EvvxH/ff1Vp4HAotP0voXEWFwMPm5YFZk79x1oNnFyxOr/f
WM4Es9J2p1vPtph7RczEKZ4UKSvjOlQ/E/NNxPP5hLs3hFouuEH/+8tr2tiDgQ66
P+EfjmFHrFEvcJ2vis1JtFgHaX9iYmuTPAD4VCY9WRLlZQhEslJOOWbNOjtKTdfY
XwIDAQAB
-----END PUBLIC KEY-----
]], _M.convert_jwk_to_pem(key).pem)
        end)
    end)
end)

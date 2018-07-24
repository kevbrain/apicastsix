local Upstream = require('apicast.upstream')
local match = require('luassert.match')

describe('Upstream', function()
    local valid_url = 'http://localhost:8080/path?query'

    describe('.new', function()
        it('returns an error on invalid upstream', function()
            assert.returns_error('invalid upstream', Upstream.new('invalid uri'))
        end)

        it('returns new instance', function()
            assert(Upstream.new(valid_url))
        end)

        it('returns table with location_name', function()
            -- @upstream location is defined in the apicast.conf file
            assert.equal('@upstream', Upstream.new(valid_url).location_name)
        end)

        it('returns table with upstream_name', function()
            -- upstream name is defined in the upstream.conf file
            assert.equal('upstream', Upstream.new(valid_url).upstream_name)
        end)

        it('returns table with resolver', function()
            assert.equal(require('resty.resolver'), Upstream.new(valid_url).resolver)
        end)
    end)

    describe(':resolve', function()
        it('uses .resolver', function()
            local upstream = Upstream.new('http://localhost:8080')
            local resolver, instance, servers = {'resolver'}, {'instance'}, {'response'}
            stub(resolver, 'instance').returns(instance)
            stub(instance, 'get_servers').returns(servers)

            upstream.resolver = resolver

            assert.equal(servers, upstream:resolve())
            assert.spy(instance.get_servers).was_called_with(instance, 'localhost', match.contains({ port = 8080 }))
        end)

        -- this is useful when we want to pre populate resolved servers in tests
        it('keeps and returns previously resolved servers', function()
            local upstream = Upstream.new(valid_url)
            local servers = { 'resolved servers instance' }
            upstream.servers = servers

            assert.equal(upstream.servers, upstream:resolve())
            assert.equal(upstream.servers, servers)
        end)
    end)

    describe(':port', function()
        it('returns port from the URI', function()
            assert.same(8090, Upstream.new('http://host:8090'):port())
        end)

        it('returns default port for the scheme when none is provided', function()
            assert.same(443, Upstream.new('https://example.com'):port())
        end)

        it('returns nil when port is unknown', function()
            assert.is_nil(Upstream.new('ftp://example.com'):port())
        end)
    end)

    describe(':set_request_host', function()
        it('sets request Host header to the URI host', function()
            stub(ngx.req, 'set_header')

            assert(Upstream.new('http://example.com/')):set_request_host()

            assert.spy(ngx.req.set_header).was_called_with('Host', 'example.com')
        end)

        it('sets request Host header to the host passed as argument', function()
            stub(ngx.req, 'set_header')

            assert(Upstream.new('http://example.com/')):set_request_host('localhost')

            assert.spy(ngx.req.set_header).was_called_with('Host', 'localhost')
        end)
    end)

    describe(':call', function()
        before_each(function()
            stub(ngx, 'exec')
            ngx.var = { }
        end)

        it('calls :resolve() when needed', function()
            local upstream = Upstream.new('http://example.com')
            stub(upstream, 'resolve')

            upstream:call({})

            assert.spy(upstream.resolve).was_called_with(upstream)
        end)

        it('does not call :resolve() when not needed', function()
            local upstream = Upstream.new('http://example.com')
            stub(upstream, 'resolve')

            upstream.servers = {}
            upstream:call({})

            assert.spy(upstream.resolve).was_not_called()
        end)

        it('stores itself in the context', function()
            local upstream = Upstream.new('http://localhost')
            local context = {}

            upstream:call(context)

            assert.equal(upstream, context[upstream.upstream_name])
        end)

        it('executes the upstream location when provided', function()
            local upstream = Upstream.new('http://localhost')

            upstream:call({})

            assert.spy(ngx.exec).was_called_with(upstream.location_name)
        end)

        it('skips executing the upstream location when missing', function()
            local upstream = Upstream.new('http://localhost')
            upstream.location_name = nil

            upstream:call({})

            assert.spy(ngx.exec).was_not_called()
        end)

        it('skips sending the response if it was already sent', function()
            ngx.headers_sent = true -- already sent response to the client
            local upstream = Upstream.new(valid_url)
            local context = { }
            spy.on(upstream, 'resolve')

            assert.returns_error('response sent already', upstream:call(context))

            assert.is_nil(context[upstream.upstream_name])
            assert.spy(upstream.resolve).was_not_called()
        end)

        describe('changes ngx.var.proxy_pass to upstream url', function()
            it('without port', function()
                local upstream = Upstream.new('http://localhost:8080/path?query')

                upstream:call({})

                assert.equal('http://upstream/path?query', ngx.var.proxy_pass)
            end)

            it('works with partial url', function()
                local upstream = Upstream.new('http://example.com')

                upstream:call({})

                assert.equal('http://upstream', ngx.var.proxy_pass)
            end)
        end)
    end)
end)

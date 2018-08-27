local ngx_variable = require('apicast.policy.ngx_variable')
local LinkedList = require('apicast.linked_list')
local context_content = require('apicast.policy.liquid_context_debug.context_content')
local cjson = require('cjson')

local LiquidContextDebug = require 'apicast.policy.liquid_context_debug'

describe('Liquid context debug policy', function()
  describe('.content', function()
    before_each(function()
      stub(ngx, 'say')
    end)

    it('calls ngx.say with the "ngx_variable" available context in JSON', function()
      -- Return something simple with just headers instead of mocking all the
      -- ngx.var.* needed.
      stub(ngx_variable, 'available_context', function(policies_context)
        return LinkedList.readonly({ headers = { some_header = 'some_val' } },
          policies_context)
      end)
      local policies_context = { a = 1 }

      LiquidContextDebug.new():content(policies_context)

      local expected_content = context_content.from(
        ngx_variable.available_context(policies_context)
      )
      local expected_json = cjson.encode(expected_content)
      assert.stub(ngx.say).was_called_with(expected_json)
    end)
  end)
end)

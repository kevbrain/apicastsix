local TemplateString = require 'apicast.template_string'
local ngx_variable = require 'apicast.policy.ngx_variable'
local LinkedList = require('apicast.linked_list')

describe('template string', function()
  before_each(function()
    -- Stub the available context to avoid depending on ngx.var.*
    stub(ngx_variable, 'available_context', function(context) return context end)
  end)

  it('renders plain text', function()
    local plain_text_template = TemplateString.new('{{ a_key }}', 'plain')
    assert.equals('{{ a_key }}', plain_text_template:render())
  end)

  it('renders liquid', function()
    local liquid_template = TemplateString.new('{{ a_key }}', 'liquid')
    assert.equals('a_value', liquid_template:render({ a_key = 'a_value' }))
  end)

  it('when rendering liquid, it can use the vars exposed in ngx_variable', function()
    stub(ngx_variable, 'available_context', function(policies_context)
      local exposed = { a_key_exposed_in_ngx_var = 'a_value' }
      return LinkedList.readonly(exposed, policies_context)
    end)

    local liquid_template = TemplateString.new('{{ a_key_exposed_in_ngx_var }}', 'liquid')
    assert.equals('a_value', liquid_template:render({}))
  end)

  it('can apply liquid filters', function()
    local liquid_template = TemplateString.new('{{ "something" | md5 }}', 'liquid')
    assert.equals(ngx.md5('something'), liquid_template:render({}))
  end)

  describe('.new', function()
    it('returns nil and an error with invalid type', function()
      local template, err = TemplateString.new('some_string', 'invalid_type')
      assert.is_nil(template)
      assert.is_not_nil(err)
    end)
  end)
end)

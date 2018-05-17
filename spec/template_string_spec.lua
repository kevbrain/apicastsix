local TemplateString = require 'apicast.template_string'

describe('template string', function()
  it('renders plain text', function()
    local plain_text_template = TemplateString.new('{{ a_key }}', 'plain')
    assert.equals('{{ a_key }}', plain_text_template:render())
  end)

  it('renders liquid', function()
    local liquid_template = TemplateString.new('{{ a_key }}', 'liquid')
    assert.equals('a_value', liquid_template:render({ a_key = 'a_value' }))
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

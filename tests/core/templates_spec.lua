-- Test suite for shooter.core.templates module
local templates = require('shooter.core.templates')

describe('templates module', function()
  describe('replace_vars', function()
    it('replaces single variable', function()
      local result = templates.replace_vars('Hello {{name}}!', { name = 'World' })
      assert.are.equal('Hello World!', result)
    end)

    it('replaces multiple variables', function()
      local result = templates.replace_vars(
        'Shot {{shot_num}} in {{repo_name}}',
        { shot_num = '42', repo_name = 'test/repo' }
      )
      assert.are.equal('Shot 42 in test/repo', result)
    end)

    it('replaces same variable multiple times', function()
      local result = templates.replace_vars(
        '{{num}} + {{num}} = {{num}}',
        { num = '5' }
      )
      assert.are.equal('5 + 5 = 5', result)
    end)

    it('handles empty template', function()
      local result = templates.replace_vars('', { foo = 'bar' })
      assert.are.equal('', result)
    end)

    it('handles nil template', function()
      local result = templates.replace_vars(nil, { foo = 'bar' })
      assert.are.equal('', result)
    end)

    it('leaves unknown variables as-is', function()
      local result = templates.replace_vars('{{known}} and {{unknown}}', { known = 'yes' })
      assert.are.equal('yes and {{unknown}}', result)
    end)

    it('leaves nil variable values unchanged', function()
      local result = templates.replace_vars('Value: {{val}}', { val = nil })
      -- nil values are not replaced, variable placeholder stays
      assert.are.equal('Value: {{val}}', result)
    end)

    it('converts numbers to strings', function()
      local result = templates.replace_vars('Number: {{num}}', { num = 42 })
      assert.are.equal('Number: 42', result)
    end)
  end)

  describe('build_vars', function()
    it('returns table with all standard variables', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {'# Test Title', '', '## shot 1', 'content'}
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local vars = templates.build_vars(bufnr, '5')

      -- Check shot variable
      assert.are.equal('5', vars.shot_num)

      -- Check file variables exist
      assert.is_string(vars.file_path)
      assert.is_string(vars.file_name)
      assert.is_string(vars.file_title)

      -- Check repo variables exist
      assert.is_string(vars.repo_name)
      assert.is_string(vars.repo_path)
    end)

    it('handles nil shot_num', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local vars = templates.build_vars(bufnr, nil)
      assert.are.equal('', vars.shot_num)
    end)
  end)

  describe('build_multishot_vars', function()
    it('includes shot_nums variable', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local vars = templates.build_multishot_vars(bufnr, {'1', '2', '3'})

      assert.are.equal('1, 2, 3', vars.shot_nums)
    end)

    it('handles single shot', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local vars = templates.build_multishot_vars(bufnr, {'42'})

      assert.are.equal('42', vars.shot_nums)
    end)
  end)

  describe('load_instructions', function()
    it('returns string for single shot', function()
      local instructions = templates.load_instructions(false)
      assert.is_string(instructions)
      assert.is_truthy(instructions:match('{{shot_num}}'))
      assert.is_truthy(instructions:match('{{file_title}}'))
    end)

    it('returns string for multishot', function()
      local instructions = templates.load_instructions(true)
      assert.is_string(instructions)
      assert.is_truthy(instructions:match('{{shot_nums}}'))
      assert.is_truthy(instructions:match('{{file_title}}'))
    end)

    it('multishot has different content than single shot', function()
      local single = templates.load_instructions(false)
      local multi = templates.load_instructions(true)
      assert.are_not.equal(single, multi)
    end)
  end)

  describe('get_repo_name', function()
    it('returns a string', function()
      local name = templates.get_repo_name()
      assert.is_string(name)
      assert.is_true(#name > 0)
    end)
  end)

  describe('get_variable_docs', function()
    it('returns markdown documentation', function()
      local docs = templates.get_variable_docs()
      assert.is_string(docs)
      assert.is_truthy(docs:match('shot_num'))
      assert.is_truthy(docs:match('file_path'))
      assert.is_truthy(docs:match('repo_name'))
    end)
  end)

  describe('load_template', function()
    it('returns nil for non-existent template', function()
      local content = templates.load_template('non-existent-template-xyz.md')
      assert.is_nil(content)
    end)

    it('loads plugin template files', function()
      local content = templates.load_template('shooter-context-instructions.md')
      -- If template exists, it should be a string
      if content then
        assert.is_string(content)
        assert.is_truthy(content:match('{{shot_num}}'))
      end
    end)
  end)
end)

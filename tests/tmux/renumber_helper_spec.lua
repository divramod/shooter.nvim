-- Test suite for shooter.tmux.renumber_helper module
local renumber_helper = require('shooter.tmux.renumber_helper')

describe('renumber_helper module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(renumber_helper.get_shot_content_hash)
      assert.is_function(renumber_helper.find_shot_by_content)
      assert.is_function(renumber_helper.renumber_and_find_shot)
    end)
  end)

  describe('get_shot_content_hash', function()
    it('returns content excluding header', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Title',
        '',
        '## shot 1',
        'Line one content',
        'Line two content',
        '',
        '## shot 2',
        'Other content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Get hash for shot 1 (lines 4-5, 0-indexed: 3-4)
      local hash = renumber_helper.get_shot_content_hash(bufnr, 3, 5)
      assert.is_truthy(hash:match('Line one content'))
      assert.is_truthy(hash:match('Line two content'))
      assert.is_falsy(hash:match('shot 1'))  -- header excluded
    end)
  end)

  describe('find_shot_by_content', function()
    it('finds shot with matching content', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Title',
        '',
        '## shot 1',
        'Unique content ABC',
        '',
        '## shot 2',
        'Different content XYZ',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local hash = 'Unique content ABC\n'
      local start_line, end_line, header_line = renumber_helper.find_shot_by_content(bufnr, hash)

      assert.are.equal(3, start_line)
      assert.are.equal(3, header_line)
    end)

    it('returns nil when no match', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Title',
        '',
        '## shot 1',
        'Some content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local start_line = renumber_helper.find_shot_by_content(bufnr, 'nonexistent content')
      assert.is_nil(start_line)
    end)
  end)
end)

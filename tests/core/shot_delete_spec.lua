-- Tests for shot delete functionality

describe('shooter.core.shot_delete', function()
  local shot_delete = require('shooter.core.shot_delete')

  local test_bufnr

  before_each(function()
    test_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(test_bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(test_bufnr, { force = true })
  end)

  describe('delete_shot_under_cursor', function()
    it('should be available as a function', function()
      assert.is_function(shot_delete.delete_shot_under_cursor)
    end)

    it('should not crash when not in a shot', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        'No shots here',
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Mock vim.fn.confirm to return "No"
      local original_confirm = vim.fn.confirm
      vim.fn.confirm = function() return 2 end

      -- Should not error
      local ok = pcall(shot_delete.delete_shot_under_cursor)
      assert.truthy(ok)

      vim.fn.confirm = original_confirm
    end)

    it('should delete an open shot when confirmed', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 2',
        'second shot content',
        '',
        '## shot 1',
        'first shot content',
      })
      vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- Inside shot 2

      -- Mock confirm to return "Yes"
      local original_confirm = vim.fn.confirm
      vim.fn.confirm = function() return 1 end

      shot_delete.delete_shot_under_cursor()

      vim.fn.confirm = original_confirm

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Shot 2 should be gone
      assert.is_nil(content:find('## shot 2'))
      assert.is_nil(content:find('second shot content'))
      -- Shot 1 should remain
      assert.truthy(content:find('## shot 1'))
      assert.truthy(content:find('first shot content'))
    end)

    it('should not delete when user cancels', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 1',
        'shot content',
      })
      vim.api.nvim_win_set_cursor(0, { 4, 0 })

      -- Mock confirm to return "No"
      local original_confirm = vim.fn.confirm
      vim.fn.confirm = function() return 2 end

      shot_delete.delete_shot_under_cursor()

      vim.fn.confirm = original_confirm

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Shot should still exist
      assert.truthy(content:find('## shot 1'))
      assert.truthy(content:find('shot content'))
    end)
  end)
end)

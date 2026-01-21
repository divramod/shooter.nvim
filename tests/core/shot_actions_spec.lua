-- Test suite for shooter.core.shot_actions module
local shot_actions = require('shooter.core.shot_actions')

describe('shot_actions module', function()
  local original_echo

  before_each(function()
    -- Mock utils.echo to avoid output during tests
    original_echo = require('shooter.utils').echo
    require('shooter.utils').echo = function() end
  end)

  after_each(function()
    require('shooter.utils').echo = original_echo
  end)

  describe('find_insertion_line (via create_new_shot)', function()
    it('inserts after title when no shots and no orphan text', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      -- Simulate create_new_shot but check buffer state
      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot should be after title
      assert.is_truthy(result[2]:match('^## shot %d+'))
    end)

    it('inserts before first shot when no orphan text', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot (## shot 2) should be inserted before shot 1
      -- Find positions of both shots
      local shot2_line = nil
      local shot1_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 2') then shot2_line = i end
        if line:match('^## shot 1') then shot1_line = i end
      end
      assert.is_not_nil(shot2_line, 'Shot 2 should exist')
      assert.is_not_nil(shot1_line, 'Shot 1 should still exist')
      assert.is_true(shot2_line < shot1_line, 'Shot 2 should be before shot 1')
    end)

    it('inserts above orphan text when orphan text exists', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        'orphan text here',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Find positions of new shot header and orphan text
      local new_shot_line = nil
      local orphan_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 2') then
          new_shot_line = i
        end
        if line == 'orphan text here' then
          orphan_line = i
        end
      end

      -- New shot should be BEFORE orphan text (orphan becomes part of new shot)
      assert.is_not_nil(new_shot_line)
      assert.is_not_nil(orphan_line)
      assert.is_true(new_shot_line < orphan_line,
        'New shot should be before orphan text, got shot=' .. tostring(new_shot_line) .. ' orphan=' .. tostring(orphan_line))
    end)

    it('handles orphan text with no existing shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        'some notes here',
        'more notes',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot should be before the orphan notes
      local new_shot_line = nil
      local notes_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 1') then
          new_shot_line = i
        end
        if line == 'some notes here' then
          notes_line = i
        end
      end

      assert.is_not_nil(new_shot_line)
      assert.is_not_nil(notes_line)
      assert.is_true(new_shot_line < notes_line)
    end)
  end)

  describe('delete_last_shot', function()
    it('deletes the highest numbered non-executed shot', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 2',
        'Shot 2 content',
        '',
        '## x shot 1',
        'Shot 1 executed',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.delete_last_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot 2 should be deleted, shot 1 should remain
      local has_shot2 = false
      local has_shot1 = false
      for _, line in ipairs(result) do
        if line:match('## shot 2') then has_shot2 = true end
        if line:match('## x shot 1') then has_shot1 = true end
      end
      assert.is_false(has_shot2)
      assert.is_true(has_shot1)
    end)

    it('refuses to delete executed shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1',
        'Shot 1 executed',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.delete_last_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot 1 should still be there
      local has_shot1 = false
      for _, line in ipairs(result) do
        if line:match('## x shot 1') then has_shot1 = true end
      end
      assert.is_true(has_shot1)
    end)
  end)
end)

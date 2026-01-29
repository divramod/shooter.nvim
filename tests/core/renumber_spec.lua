-- Tests for shooter.core.renumber
local renumber = require('shooter.core.renumber')
local utils = require('shooter.utils')

describe('shooter.core.renumber', function()
  local test_bufnr

  before_each(function()
    test_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(test_bufnr)
    -- Set a temp filename so write works
    vim.api.nvim_buf_set_name(test_bufnr, '/tmp/test_renumber_' .. os.time() .. '.md')
  end)

  after_each(function()
    local name = vim.api.nvim_buf_get_name(test_bufnr)
    pcall(vim.api.nvim_buf_delete, test_bufnr, { force = true })
    if name ~= '' then os.remove(name) end
  end)

  describe('renumber_shots', function()
    it('should renumber shots with gaps', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 5',
        'content for shot 5',
        '',
        '## shot 10',
        'content for shot 10',
        '',
        '## shot 15',
        'content for shot 15',
      })

      local count = renumber.renumber_shots(test_bufnr)

      assert.equals(3, count)
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')
      assert.truthy(content:find('## shot 1\n'))
      assert.truthy(content:find('## shot 2\n'))
      assert.truthy(content:find('## shot 3\n'))
      assert.is_nil(content:find('## shot 5'))
      assert.is_nil(content:find('## shot 10'))
      assert.is_nil(content:find('## shot 15'))
    end)

    it('should sort done shots by timestamp before open shots', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 1',
        'open shot',
        '',
        '## x shot 2 (2026-01-29 10:00:00)',
        'newer done shot',
        '',
        '## x shot 3 (2026-01-28 10:00:00)',
        'older done shot',
      })

      renumber.renumber_shots(test_bufnr)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Find positions of each shot
      local older_pos = content:find('older done shot')
      local newer_pos = content:find('newer done shot')
      local open_pos = content:find('open shot')

      -- Older done shot should come first
      assert.truthy(older_pos < newer_pos)
      -- Both done shots should come before open shot
      assert.truthy(newer_pos < open_pos)
    end)

    it('should preserve content of each shot', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 99',
        'unique content ABC123',
        'more content XYZ789',
      })

      renumber.renumber_shots(test_bufnr)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')
      assert.truthy(content:find('unique content ABC123'))
      assert.truthy(content:find('more content XYZ789'))
    end)

    it('should handle shot 0 correctly', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 0',
        'shot zero content',
        '',
        '## shot 1',
        'shot one content',
      })

      renumber.renumber_shots(test_bufnr)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')
      -- Shot 0 becomes shot 1, shot 1 becomes shot 2
      assert.truthy(content:find('## shot 1\nshot zero'))
      assert.truthy(content:find('## shot 2\nshot one'))
    end)

    it('should return 0 when no shots found', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        'No shots here',
      })

      local count = renumber.renumber_shots(test_bufnr)
      assert.equals(0, count)
    end)

    it('should handle "shot ?" and keep position among open shots', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## x shot 1 (2026-01-28 10:00:00)',
        'done shot',
        '',
        '## shot 5',
        'open shot A',
        '',
        '## shot ?',
        'unnumbered shot',
        '',
        '## shot 10',
        'open shot B',
      })

      local count = renumber.renumber_shots(test_bufnr)

      assert.equals(4, count)
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Done shot should be first (shot 1)
      -- Then open shots in order: shot 5 -> shot 2, shot ? -> shot 3, shot 10 -> shot 4
      assert.truthy(content:find('## x shot 1'))
      assert.truthy(content:find('done shot'))

      -- Find positions to verify order
      local done_pos = content:find('done shot')
      local open_a_pos = content:find('open shot A')
      local unnumbered_pos = content:find('unnumbered shot')
      local open_b_pos = content:find('open shot B')

      assert.truthy(done_pos < open_a_pos)
      assert.truthy(open_a_pos < unnumbered_pos)
      assert.truthy(unnumbered_pos < open_b_pos)

      -- Verify shot ? got a number
      assert.is_nil(content:find('shot %?'))
    end)
  end)
end)

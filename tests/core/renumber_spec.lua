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

    it('should put open shots at top and done shots at bottom', function()
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

      -- Open shot should come first (top)
      assert.truthy(open_pos < older_pos)
      -- Done shots at bottom, sorted by timestamp (older before newer)
      assert.truthy(older_pos < newer_pos)
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
      -- With reversed numbering: first shot (shot 0) becomes shot 2, second (shot 1) becomes shot 1
      assert.truthy(content:find('## shot 2\nshot zero'))
      assert.truthy(content:find('## shot 1\nshot one'))
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

      -- With reversed numbering: first shot gets highest (4), last gets lowest (1)
      -- Order: open A (shot 4), unnumbered (shot 3), open B (shot 2), done (shot 1)
      assert.truthy(content:find('## x shot 1'))
      assert.truthy(content:find('done shot'))

      -- Find positions to verify order (open shots first, done last)
      local done_pos = content:find('done shot')
      local open_a_pos = content:find('open shot A')
      local unnumbered_pos = content:find('unnumbered shot')
      local open_b_pos = content:find('open shot B')

      -- Open shots at top in original order, done shot at bottom
      assert.truthy(open_a_pos < unnumbered_pos)
      assert.truthy(unnumbered_pos < open_b_pos)
      assert.truthy(open_b_pos < done_pos)

      -- Verify shot ? got a number
      assert.is_nil(content:find('shot %?'))
    end)

    it('should handle decimal shot numbers (1.1, 1.2)', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 1.1',
        'decimal shot A',
        '',
        '## shot 1.2',
        'decimal shot B',
        '',
        '## shot 2',
        'regular shot',
      })

      local count = renumber.renumber_shots(test_bufnr)

      assert.equals(3, count)
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- All decimal numbers should be replaced with integers
      assert.is_nil(content:find('shot 1%.1'))
      assert.is_nil(content:find('shot 1%.2'))
      -- Should have sequential numbers (reversed: first=3, last=1)
      assert.truthy(content:find('## shot 3\n'))
      assert.truthy(content:find('## shot 2\n'))
      assert.truthy(content:find('## shot 1\n'))
    end)

    it('should handle negative shot numbers (-1, -2)', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot -2',
        'negative shot A',
        '',
        '## shot -1',
        'negative shot B',
        '',
        '## shot 1',
        'positive shot',
      })

      local count = renumber.renumber_shots(test_bufnr)

      assert.equals(3, count)
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- All negative numbers should be replaced with positive integers
      assert.is_nil(content:find('shot %-2'))
      assert.is_nil(content:find('shot %-1'))
      -- Should have sequential numbers (reversed: first=3, last=1)
      assert.truthy(content:find('## shot 3\n'))
      assert.truthy(content:find('## shot 2\n'))
      assert.truthy(content:find('## shot 1\n'))
    end)

    it('should handle mixed formats (decimal, negative, ?, regular)', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot -1',
        'negative',
        '',
        '## shot 1.5',
        'decimal',
        '',
        '## shot ?',
        'question mark',
        '',
        '## shot 99',
        'regular',
      })

      local count = renumber.renumber_shots(test_bufnr)

      assert.equals(4, count)
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- All special formats should be replaced
      assert.is_nil(content:find('shot %-1'))
      assert.is_nil(content:find('shot 1%.5'))
      assert.is_nil(content:find('shot %?'))
      assert.is_nil(content:find('shot 99'))

      -- Content should be preserved in order
      local neg_pos = content:find('negative')
      local dec_pos = content:find('decimal')
      local qm_pos = content:find('question mark')
      local reg_pos = content:find('regular')

      assert.truthy(neg_pos < dec_pos)
      assert.truthy(dec_pos < qm_pos)
      assert.truthy(qm_pos < reg_pos)
    end)
  end)
end)

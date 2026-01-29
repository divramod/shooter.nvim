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
      -- Sorted by number desc: shot 1 first, shot 0 second
      -- With reversed numbering: shot 1 becomes shot 2, shot 0 becomes shot 1
      assert.truthy(content:find('## shot 2\nshot one'))
      assert.truthy(content:find('## shot 1\nshot zero'))
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

    it('should handle "shot ?" and sort by number', function()
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

      -- Sorted by number desc: shot 10 first, shot 5 second, shot ? (=0) third
      -- With reversed numbering: shot 10→4, shot 5→3, shot ?→2, done→1
      assert.truthy(content:find('## x shot 1'))
      assert.truthy(content:find('done shot'))

      -- Find positions to verify order (sorted by number desc, done last)
      local done_pos = content:find('done shot')
      local open_a_pos = content:find('open shot A')
      local unnumbered_pos = content:find('unnumbered shot')
      local open_b_pos = content:find('open shot B')

      -- Open shots sorted by number desc: B (10) < A (5) < ? (0), then done
      assert.truthy(open_b_pos < open_a_pos)
      assert.truthy(open_a_pos < unnumbered_pos)
      assert.truthy(unnumbered_pos < done_pos)

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
      -- Sorted by number desc: 2 > 1.2 > 1.1
      -- regular shot → shot 3, decimal B → shot 2, decimal A → shot 1
      assert.truthy(content:find('## shot 3\nregular'))
      assert.truthy(content:find('## shot 2\ndecimal shot B'))
      assert.truthy(content:find('## shot 1\ndecimal shot A'))
    end)

    it('should place 2.1 between 2 and 3 (becomes shot 3)', function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        '# Test File',
        '',
        '## shot 3',
        'shot three',
        '',
        '## shot 2.1',
        'inserted shot',
        '',
        '## shot 2',
        'shot two',
      })

      renumber.renumber_shots(test_bufnr)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Sorted by number desc: 3 > 2.1 > 2
      -- shot 3 → shot 3, shot 2.1 → shot 2, shot 2 → shot 1
      local three_pos = content:find('shot three')
      local inserted_pos = content:find('inserted shot')
      local two_pos = content:find('shot two')

      assert.truthy(three_pos < inserted_pos)
      assert.truthy(inserted_pos < two_pos)
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

      -- Sorted by number desc: 99 > 1.5 > 0 (?) > -1
      local neg_pos = content:find('negative')
      local dec_pos = content:find('decimal')
      local qm_pos = content:find('question mark')
      local reg_pos = content:find('regular')

      assert.truthy(reg_pos < dec_pos)
      assert.truthy(dec_pos < qm_pos)
      assert.truthy(qm_pos < neg_pos)
    end)
  end)
end)

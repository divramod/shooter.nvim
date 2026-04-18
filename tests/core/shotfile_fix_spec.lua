-- Tests for shooter.core.shotfile_fix
local shotfile_fix = require('shooter.core.shotfile_fix')

describe('shooter.core.shotfile_fix', function()
  describe('header_has_no_title', function()
    it('true for bare "## shot 5"', function()
      assert.is_true(shotfile_fix.header_has_no_title('## shot 5'))
    end)

    it('true with trailing whitespace', function()
      assert.is_true(shotfile_fix.header_has_no_title('## shot 5   '))
    end)

    it('true for executed header with only timestamp', function()
      assert.is_true(shotfile_fix.header_has_no_title(
        '## x shot 2 (2026-01-29 10:00:00)'))
    end)

    it('false when header has a title', function()
      assert.is_false(shotfile_fix.header_has_no_title(
        '## shot 5 HalShooterShotfileFix'))
    end)

    it('false when header has title and timestamp', function()
      assert.is_false(shotfile_fix.header_has_no_title(
        '## x shot 5 HalShooterShotfileFix (2026-04-14 06:04:44)'))
    end)

    it('true for decimal shot without title', function()
      assert.is_true(shotfile_fix.header_has_no_title('## shot 2.1'))
    end)

    it('true for question mark shot', function()
      assert.is_true(shotfile_fix.header_has_no_title('## shot ?'))
    end)
  end)

  describe('strip_empty_shots', function()
    it('removes an open empty shot', function()
      local lines = {
        '# feats',
        '',
        '## shot 5',
        '',
        '## shot 4',
        'some content',
        '',
        '## shot 3 hello',
        'more',
      }
      local out, removed = shotfile_fix.strip_empty_shots(lines)
      assert.equals(1, removed)
      local joined = table.concat(out, '\n')
      assert.is_nil(joined:find('## shot 5'))
      assert.truthy(joined:find('## shot 4'))
      assert.truthy(joined:find('## shot 3 hello'))
    end)

    it('keeps shot with title but no body', function()
      local lines = { '## shot 1 something' }
      local _, removed = shotfile_fix.strip_empty_shots(lines)
      assert.equals(0, removed)
    end)

    it('keeps open shot with body but no title', function()
      local lines = { '## shot 1', 'body line' }
      local _, removed = shotfile_fix.strip_empty_shots(lines)
      assert.equals(0, removed)
    end)

    it('does not remove executed empty shots', function()
      local lines = { '## x shot 1 (2026-01-29 10:00:00)' }
      local _, removed = shotfile_fix.strip_empty_shots(lines)
      assert.equals(0, removed)
    end)

    it('ignores shot-like lines inside fenced code blocks', function()
      local lines = {
        '# feats',
        '',
        '## shot 1 real',
        'body',
        '',
        '```markdown',
        '## shot 2',
        '```',
      }
      local _, removed = shotfile_fix.strip_empty_shots(lines)
      assert.equals(0, removed)
    end)

    it('removes multiple empty shots', function()
      local lines = {
        '# f', '',
        '## shot 3', '',
        '## shot 2 title', 'body',
        '## shot 1', '',
      }
      local out, removed = shotfile_fix.strip_empty_shots(lines)
      assert.equals(2, removed)
      local joined = table.concat(out, '\n')
      assert.truthy(joined:find('## shot 2 title'))
      assert.is_nil(joined:find('## shot 3'))
      assert.is_nil(joined:find('## shot 1'))
    end)
  end)

  describe('fix_buffer', function()
    local bufnr
    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_buf_set_name(bufnr, '/tmp/test_shotfile_fix_' .. os.time() .. '.md')
    end)
    after_each(function()
      local name = vim.api.nvim_buf_get_name(bufnr)
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      if name ~= '' then os.remove(name) end
    end)

    it('strips empty shots and renumbers remaining', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '# f',
        '',
        '## shot 5',
        '',
        '## shot 4',
        'content',
        '',
        '## shot 3 hi',
        'more',
      })
      local stats = shotfile_fix.fix_buffer(bufnr)
      assert.equals(1, stats.removed)
      assert.equals(2, stats.renumbered)
      local joined = table.concat(
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
      assert.is_nil(joined:find('## shot 5\n'))
      assert.truthy(joined:find('## shot 2'))
      assert.truthy(joined:find('## shot 1'))
    end)

    it('strips trailing blank lines at end of buffer', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '# f',
        '',
        '## shot 1 only',
        'body',
        '',
        '',
        '   ',
        '',
      })
      shotfile_fix.fix_buffer(bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.truthy(#lines > 0)
      assert.not_equals('', lines[#lines])
      assert.is_nil(lines[#lines]:match('^%s*$'))
      assert.equals('body', lines[#lines])
    end)

    it('normalizes multiple blank lines above ## shot to one', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '# f',
        '',
        '',
        '',
        '## shot 1 first',
        'body',
        '',
        '',
        '',
        '## shot 2 second',
        'body',
      })
      shotfile_fix.fix_buffer(bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i = 2, #lines do
        if lines[i]:match('^## shot') then
          assert.equals('', lines[i - 1])
          if i >= 3 then
            assert.not_equals('', lines[i - 2])
          end
        end
      end
    end)
  end)
end)

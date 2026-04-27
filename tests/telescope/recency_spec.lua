local recency = require('shooter.telescope.recency')

describe('shooter.telescope.recency', function()
  describe('format_relative', function()
    it('formats seconds for < 60s', function()
      assert.equals('0s ago', recency.format_relative(0))
      assert.equals('59s ago', recency.format_relative(59))
    end)

    it('formats minutes', function()
      assert.equals('1m ago', recency.format_relative(60))
      assert.equals('5m ago', recency.format_relative(300))
    end)

    it('formats hours and minutes', function()
      assert.equals('2h ago', recency.format_relative(7200))
      assert.equals('2h 5m ago', recency.format_relative(2 * 3600 + 5 * 60))
    end)

    it('formats days', function()
      assert.equals('1d ago', recency.format_relative(86400))
      assert.equals('3d ago', recency.format_relative(3 * 86400))
    end)

    it('formats weeks', function()
      assert.equals('1w ago', recency.format_relative(7 * 86400))
      assert.equals('2w ago', recency.format_relative(14 * 86400))
    end)

    it('formats months', function()
      assert.equals('1mo ago', recency.format_relative(30 * 86400))
    end)

    it('formats years', function()
      assert.equals('1y ago', recency.format_relative(365 * 86400))
    end)
  end)

  describe('sort_desc', function()
    it('sorts entries by mtime descending', function()
      local dir = '/tmp/shooter_recency_test'
      os.execute('rm -rf ' .. dir)
      os.execute('mkdir -p ' .. dir)
      local paths = { dir .. '/a.md', dir .. '/b.md', dir .. '/c.md' }
      for i, p in ipairs(paths) do
        local f = io.open(p, 'w')
        if f then f:write('x'); f:close() end
        -- Stagger mtimes: a=oldest, c=newest
        vim.loop.fs_utime(p, os.time() - (3 - i) * 100, os.time() - (3 - i) * 100)
      end
      local entries = {
        { path = paths[1], display = 'a.md' },
        { path = paths[2], display = 'b.md' },
        { path = paths[3], display = 'c.md' },
      }
      recency.sort_desc(entries)
      assert.equals('c.md', entries[1].display)
      assert.equals('b.md', entries[2].display)
      assert.equals('a.md', entries[3].display)
      os.execute('rm -rf ' .. dir)
    end)
  end)

  describe('append_age', function()
    it('appends a relative time suffix', function()
      local now = 1000000
      assert.equals('foo.md (5m ago)', recency.append_age('foo.md', now - 300, now))
      assert.equals('foo.md (1d ago)', recency.append_age('foo.md', now - 86400, now))
    end)
  end)
end)

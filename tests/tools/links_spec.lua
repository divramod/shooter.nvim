local links = require('shooter.tools.links')

describe('shooter.tools.links', function()
  describe('extract_target', function()
    it('extracts URL from markdown inline link', function()
      assert.equals('https://example.com',
        links.extract_target('[foo](https://example.com)'))
    end)

    it('extracts path from markdown link', function()
      assert.equals('./foo.md',
        links.extract_target('[foo](./foo.md)'))
    end)

    it('returns plain tokens unchanged', function()
      assert.equals('https://x.io', links.extract_target('https://x.io'))
      assert.equals('./bar', links.extract_target('./bar'))
    end)

    it('handles angle-bracketed URL', function()
      assert.equals('https://x.io', links.extract_target('<https://x.io>'))
    end)
  end)

  describe('classify', function()
    it('classifies http(s) as web', function()
      assert.equals('web', links.classify('http://x.io'))
      assert.equals('web', links.classify('https://x.io/a'))
    end)

    it('classifies obsidian:// as web', function()
      assert.equals('web', links.classify('obsidian://open?vault=foo'))
    end)

    it('classifies existing directory', function()
      os.execute('mkdir -p /tmp/shooter_links_test_dir')
      assert.equals('dir', links.classify('/tmp/shooter_links_test_dir'))
      os.execute('rm -rf /tmp/shooter_links_test_dir')
    end)

    it('classifies existing file', function()
      os.execute('touch /tmp/shooter_links_test_file.md')
      assert.equals('file', links.classify('/tmp/shooter_links_test_file.md'))
      os.execute('rm -f /tmp/shooter_links_test_file.md')
    end)

    it('classifies missing path as other', function()
      assert.equals('other', links.classify('/tmp/nonexistent-xyzzy.md'))
    end)

    it('classifies trailing-slash tokens as dir', function()
      assert.equals('dir', links.classify('/some/where/'))
    end)
  end)

  describe('link_picker.format_entry', function()
    local link_picker = require('shooter.telescope.link_picker')

    it('formats web entry without an age suffix', function()
      local entry = {
        line = 42, col = 7, target = 'https://example.com', kind = 'web',
      }
      local out = link_picker.format_entry(entry, false)
      assert.truthy(out:find('https://example.com', 1, true))
      assert.truthy(out:find('(42:7)', 1, true))
      assert.is_nil(out:find('ago', 1, true))
    end)

    it('prepends [source] when with_source is true', function()
      local entry = {
        line = 1, col = 0, target = 'https://x.io', kind = 'web', source = 'nvim',
      }
      local out = link_picker.format_entry(entry, true)
      assert.truthy(out:find('^%[nvim%]'))
      assert.truthy(out:find('https://x.io', 1, true))
      assert.truthy(out:find('(1:0)', 1, true))
    end)

    it('appends relative age suffix for existing file links', function()
      local path = '/tmp/shooter_linkpicker_age.md'
      os.execute('touch ' .. path)
      -- Force mtime to 5 minutes before the "now" we pass.
      local now = os.time()
      vim.loop.fs_utime(path, now - 300, now - 300)

      local entry = { line = 3, col = 2, target = path, kind = 'file' }
      local out = link_picker.format_entry(entry, false, now)
      assert.truthy(out:find(path, 1, true))
      assert.truthy(out:find('(3:2)', 1, true))
      assert.truthy(out:find('(5m ago)', 1, true))
      os.execute('rm -f ' .. path)
    end)

    it('appends age suffix for existing directory links', function()
      local dir = '/tmp/shooter_linkpicker_age_dir'
      os.execute('mkdir -p ' .. dir)
      local now = os.time()
      vim.loop.fs_utime(dir, now - 7200, now - 7200)

      local entry = { line = 1, col = 0, target = dir, kind = 'dir' }
      local out = link_picker.format_entry(entry, false, now)
      assert.truthy(out:find('(2h ago)', 1, true))
      os.execute('rm -rf ' .. dir)
    end)

    describe('compute_width', function()
      it('keeps the narrow default when everything fits', function()
        -- max_display 50 + padding 6 = 56, default = 80% of 200 = 160.
        assert.equals(160, link_picker.compute_width(50, 200, 6))
      end)

      it('expands to full width when any entry exceeds the default', function()
        -- max_display 180 + padding 6 = 186 > 160 (80% of 200) → full cols.
        assert.equals(200, link_picker.compute_width(180, 200, 6))
      end)

      it('returns full cols on tiny windows', function()
        -- default would be 40 * 0.8 = 32; max_display 50 exceeds → cols.
        assert.equals(40, link_picker.compute_width(50, 40, 6))
      end)
    end)

    it('omits age when the target does not exist', function()
      local entry = {
        line = 1, col = 0, target = '/tmp/nonexistent-xxxxx.md', kind = 'file',
      }
      local out = link_picker.format_entry(entry, false, os.time())
      assert.is_nil(out:find('ago', 1, true))
    end)
  end)

  describe('collect_from_lines', function()
    it('finds links across multiple lines with positions', function()
      local lines = {
        'prose only',
        'see https://a.io here',
        'and [docs](./docs.md) there',
      }
      local out = links.collect_from_lines(lines)
      assert.equals(2, #out)
      assert.equals(2, out[1].line)
      assert.equals('https://a.io', out[1].target)
      assert.equals('web', out[1].kind)
      assert.equals(3, out[2].line)
      assert.equals('./docs.md', out[2].target)
    end)

    it('passes source label through', function()
      local out = links.collect_from_lines({ 'https://x.io' }, 'nvim')
      assert.equals('nvim', out[1].source)
    end)
  end)
end)

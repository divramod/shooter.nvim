-- Tests for shooter.history.sync
local sync = require('shooter.history.sync')
local utils = require('shooter.utils')

describe('shooter.history.sync', function()
  local test_dir = '/tmp/shooter_sync_test'
  local history_dir = test_dir .. '/history/local/test-repo/_root/test-file'

  before_each(function()
    os.execute('mkdir -p ' .. history_dir)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_dir)
  end)

  describe('parse_frontmatter', function()
    it('should parse valid frontmatter', function()
      local filepath = test_dir .. '/test.md'
      local content = [[---
shot: 42
source: /path/to/file.md
repo: user/repo
timestamp: 2026-01-23 10:00:00
---

# Content
]]
      utils.write_file(filepath, content)

      local fm = sync.parse_frontmatter(filepath)
      assert.is_not_nil(fm)
      assert.equals('42', fm.shot)
      assert.equals('/path/to/file.md', fm.source)
      assert.equals('user/repo', fm.repo)
      assert.equals('2026-01-23 10:00:00', fm.timestamp)
    end)

    it('should return nil for files without frontmatter', function()
      local filepath = test_dir .. '/test.md'
      utils.write_file(filepath, '# Just content\nNo frontmatter here')

      local fm = sync.parse_frontmatter(filepath)
      assert.is_nil(fm)
    end)
  end)

  describe('update_frontmatter_field', function()
    it('should update existing field', function()
      local filepath = test_dir .. '/test.md'
      local content = [[---
shot: 42
source: /old/path.md
repo: user/repo
---

# Content
]]
      utils.write_file(filepath, content)

      local result = sync.update_frontmatter_field(filepath, 'source', '/new/path.md')
      assert.is_true(result)

      local updated = utils.read_file(filepath)
      assert.truthy(updated:find('source: /new/path.md'))
      assert.falsy(updated:find('source: /old/path.md'))
    end)

    it('should return false if field not found', function()
      local filepath = test_dir .. '/test.md'
      utils.write_file(filepath, '---\nshot: 1\n---\n')

      local result = sync.update_frontmatter_field(filepath, 'nonexistent', 'value')
      assert.is_false(result)
    end)
  end)

  describe('get_history_files', function()
    it('should return shot files in folder', function()
      utils.write_file(history_dir .. '/shot-0001-20260123_100000.md', 'test')
      utils.write_file(history_dir .. '/shot-0002-20260123_110000.md', 'test')
      utils.write_file(history_dir .. '/other.md', 'test')

      local files = sync.get_history_files(history_dir)
      assert.equals(2, #files)
    end)

    it('should return empty for nonexistent folder', function()
      local files = sync.get_history_files('/nonexistent/path')
      assert.equals(0, #files)
    end)
  end)

  describe('update_source_paths', function()
    it('should update source in all history files', function()
      local file1 = history_dir .. '/shot-0001-20260123_100000.md'
      local file2 = history_dir .. '/shot-0002-20260123_110000.md'

      utils.write_file(file1, '---\nshot: 1\nsource: /old/file.md\n---\nContent')
      utils.write_file(file2, '---\nshot: 2\nsource: /old/file.md\n---\nContent')

      local count = sync.update_source_paths(history_dir, '/new/file.md')
      assert.equals(2, count)

      local content1 = utils.read_file(file1)
      local content2 = utils.read_file(file2)
      assert.truthy(content1:find('source: /new/file.md'))
      assert.truthy(content2:find('source: /new/file.md'))
    end)
  end)

  describe('build_history_folder_path', function()
    it('should return nil for nil input', function()
      local path = sync.build_history_folder_path(nil)
      assert.is_nil(path)
    end)
  end)
end)

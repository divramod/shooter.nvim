-- Test suite for shooter.history module
local history = require('shooter.history')
local migrate = require('shooter.history.migrate')

describe('history module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(history.get_git_remote_info)
      assert.is_function(history.get_history_base_dir)
      assert.is_function(history.format_shot_number)
      assert.is_function(history.get_file_timestamp)
      assert.is_function(history.detect_project_from_path)
      assert.is_function(history.build_history_path)
      assert.is_function(history.save_shot)
      assert.is_function(history.save_sendable)
      assert.is_function(history.list_history)
      assert.is_function(history.migrate_history_files)
    end)
  end)

  describe('format_shot_number', function()
    it('formats single digit numbers with leading zeros', function()
      assert.are.equal('0007', history.format_shot_number(7))
    end)

    it('formats double digit numbers with leading zeros', function()
      assert.are.equal('0042', history.format_shot_number(42))
    end)

    it('formats triple digit numbers with leading zero', function()
      assert.are.equal('0197', history.format_shot_number(197))
    end)

    it('formats four digit numbers without change', function()
      assert.are.equal('1234', history.format_shot_number(1234))
    end)

    it('handles string input', function()
      assert.are.equal('0007', history.format_shot_number('7'))
    end)

    it('handles multi-shot format with dash', function()
      assert.are.equal('0170-0169', history.format_shot_number('170-169'))
    end)
  end)

  describe('get_file_timestamp', function()
    it('returns timestamp in correct format', function()
      local ts = history.get_file_timestamp()
      assert.is_string(ts)
      assert.is_truthy(ts:match('^%d%d%d%d%d%d%d%d_%d%d%d%d%d%d$'))
    end)
  end)

  describe('build_history_path', function()
    it('builds correct path with timestamp and default project', function()
      local filepath, dirpath = history.build_history_path('user', 'repo', 'test.md', 42, '20260121_143000')
      assert.is_truthy(filepath:match('user/repo/_root/test/shot%-0042%-20260121_143000%.md$'))
      assert.is_truthy(dirpath:match('user/repo/_root/test$'))
    end)

    it('builds correct path with explicit project', function()
      local filepath, dirpath = history.build_history_path('user', 'repo', 'test.md', 42, '20260121_143000', 'myproject')
      assert.is_truthy(filepath:match('user/repo/myproject/test/shot%-0042%-20260121_143000%.md$'))
      assert.is_truthy(dirpath:match('user/repo/myproject/test$'))
    end)

    it('removes extension from source filename', function()
      local filepath = history.build_history_path('user', 'repo', 'myfile.md', 1, '20260121_143000')
      assert.is_truthy(filepath:match('/myfile/'))
      assert.is_falsy(filepath:match('/myfile%.md/'))
    end)

    it('generates timestamp when not provided', function()
      local filepath = history.build_history_path('user', 'repo', 'test.md', 1)
      assert.is_truthy(filepath:match('shot%-0001%-%d%d%d%d%d%d%d%d_%d%d%d%d%d%d%.md$'))
    end)
  end)

  describe('detect_project_from_path', function()
    it('returns _root for nil path', function()
      local result = history.detect_project_from_path(nil)
      assert.are.equal('_root', result)
    end)

    it('returns _root for path not in projects folder', function()
      local result = history.detect_project_from_path('/some/path/plans/prompts/file.md')
      assert.are.equal('_root', result)
    end)
  end)

  describe('get_history_base_dir', function()
    it('returns path under .config/shooter.nvim', function()
      local dir = history.get_history_base_dir()
      assert.is_truthy(dir:match('shooter%.nvim/history$'))
    end)
  end)
end)

describe('migrate module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(migrate.is_new_format)
      assert.is_function(migrate.is_old_format)
      assert.is_function(migrate.extract_timestamp_for_filename)
      assert.is_function(migrate.migrate_history_files)
    end)
  end)

  describe('is_new_format', function()
    it('returns true for new format with timestamp', function()
      assert.is_true(migrate.is_new_format('shot-0042-20260121_143000.md'))
    end)

    it('returns true for four digit shot number', function()
      assert.is_true(migrate.is_new_format('shot-0197-20260121_200831.md'))
    end)

    it('returns false for old format without timestamp', function()
      assert.is_false(migrate.is_new_format('shot-0042.md'))
    end)

    it('returns false for other file types', function()
      assert.is_false(migrate.is_new_format('send-0042.md'))
    end)
  end)

  describe('is_old_format', function()
    it('returns true for old format without timestamp', function()
      assert.is_true(migrate.is_old_format('shot-0042.md'))
    end)

    it('returns true for multi-shot format', function()
      assert.is_true(migrate.is_old_format('shot-0170-0169.md'))
    end)

    it('returns false for new format with timestamp', function()
      assert.is_false(migrate.is_old_format('shot-0042-20260121_143000.md'))
    end)

    it('returns false for non-shot files', function()
      assert.is_false(migrate.is_old_format('send-0042.md'))
    end)
  end)

  describe('extract_timestamp_for_filename', function()
    it('extracts timestamp from YAML frontmatter', function()
      local content = [[---
shot: 42
timestamp: 2026-01-21 14:30:00
---
# Content]]
      local ts = migrate.extract_timestamp_for_filename(content)
      assert.are.equal('20260121_143000', ts)
    end)

    it('returns nil for content without timestamp', function()
      local content = [[---
shot: 42
---
# Content]]
      local ts = migrate.extract_timestamp_for_filename(content)
      assert.is_nil(ts)
    end)

    it('returns nil for nil content', function()
      local ts = migrate.extract_timestamp_for_filename(nil)
      assert.is_nil(ts)
    end)

    it('handles different timestamp formats', function()
      local content = [[---
timestamp: 2025-12-31 23:59:59
---]]
      local ts = migrate.extract_timestamp_for_filename(content)
      assert.are.equal('20251231_235959', ts)
    end)
  end)
end)

-- Tests for shooter.history.audit
local audit = require('shooter.history.audit')
local utils = require('shooter.utils')

describe('shooter.history.audit', function()
  local test_dir = '/tmp/shooter_audit_test'

  before_each(function()
    os.execute('mkdir -p ' .. test_dir)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_dir)
  end)

  describe('parse_done_shot', function()
    it('should parse done shot with date', function()
      local num, date = audit.parse_done_shot('## x shot 42 (2026-01-23 10:30:00)')
      assert.equals(42, num)
      assert.equals('2026-01-23 10:30:00', date)
    end)

    it('should parse done shot without date', function()
      local num, date = audit.parse_done_shot('## x shot 15')
      assert.equals(15, num)
      assert.is_nil(date)
    end)

    it('should return nil for open shot', function()
      local num, date = audit.parse_done_shot('## shot 5')
      assert.is_nil(num)
      assert.is_nil(date)
    end)

    it('should return nil for non-shot lines', function()
      local num, date = audit.parse_done_shot('# Some heading')
      assert.is_nil(num)
      assert.is_nil(date)
    end)
  end)

  describe('subtract_minute', function()
    it('should subtract one minute', function()
      local result = audit.subtract_minute('2026-01-23 10:30:00')
      assert.equals('2026-01-23 10:29:00', result)
    end)

    it('should handle hour boundary', function()
      local result = audit.subtract_minute('2026-01-23 10:00:00')
      assert.equals('2026-01-23 09:59:00', result)
    end)

    it('should handle day boundary', function()
      local result = audit.subtract_minute('2026-01-23 00:00:00')
      assert.equals('2026-01-22 23:59:00', result)
    end)
  end)

  describe('get_shot_content', function()
    it('should extract content until next header', function()
      local lines = {
        '## x shot 2 (2026-01-23 10:00:00)',
        'This is the content',
        'More content here',
        '',
        '## x shot 1 (2026-01-23 09:00:00)',
        'First shot content',
      }

      local content = audit.get_shot_content(lines, 1)
      assert.equals('This is the content\nMore content here', content)
    end)

    it('should handle last shot in file', function()
      local lines = {
        '## x shot 1 (2026-01-23 10:00:00)',
        'Only shot content',
        'Second line',
      }

      local content = audit.get_shot_content(lines, 1)
      assert.equals('Only shot content\nSecond line', content)
    end)
  end)

  describe('fix_shots_missing_dates', function()
    it('should fix shots without dates by deriving from next shot', function()
      local filepath = test_dir .. '/test.md'
      local content = [[# test

## x shot 3
Missing date content

## x shot 2 (2026-01-23 10:30:00)
Has date

## x shot 1
Also missing date
]]
      utils.write_file(filepath, content)

      local fixed, shots = audit.fix_shots_missing_dates(filepath, true)
      assert.equals(2, fixed)

      local new_content = utils.read_file(filepath)
      assert.truthy(new_content:find('## x shot 3 %(2026%-01%-23 10:29:00%)'))
      -- Shot 1 should use file mtime since no shot after it has a date
    end)

    it('should not modify file when do_fix is false', function()
      local filepath = test_dir .. '/test.md'
      local content = '## x shot 1\nContent'
      utils.write_file(filepath, content)

      local fixed = audit.fix_shots_missing_dates(filepath, false)
      assert.equals(1, fixed)

      local new_content = utils.read_file(filepath)
      assert.equals(content, new_content)
    end)
  end)
end)

-- Tests for shooter.history.audit_runner
local audit_runner = require('shooter.history.audit_runner')
local utils = require('shooter.utils')

describe('shooter.history.audit_runner', function()
  local test_dir = '/tmp/shooter_audit_runner_test'

  before_each(function()
    os.execute('mkdir -p ' .. test_dir)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_dir)
  end)

  describe('get_reports_dir', function()
    it('should return reports directory path', function()
      local dir = audit_runner.get_reports_dir()
      assert.truthy(dir:match('audit%-reports$'))
    end)
  end)

  describe('generate_report_path', function()
    it('should generate timestamped report path', function()
      local path = audit_runner.generate_report_path()
      assert.truthy(path:match('audit%-reports/audit%-%d+_%d+%.md$'))
    end)
  end)

  describe('generate_report', function()
    it('should generate markdown report with summary', function()
      local results = {
        files_checked = 10,
        dates_fixed = 2,
        history_created = 3,
        details = {}
      }

      local report = audit_runner.generate_report(results, false)
      assert.truthy(report:match('# Shooter History Audit Report'))
      assert.truthy(report:match('Files checked | 10'))
      assert.truthy(report:match('Shots missing dates | 2'))
      assert.truthy(report:match('Missing history entries | 3'))
    end)

    it('should include details when present', function()
      local results = {
        files_checked = 1,
        dates_fixed = 1,
        history_created = 0,
        details = {
          { file = '/path/to/test.md', dates_fixed = 1, history_missing = 0 }
        }
      }

      local report = audit_runner.generate_report(results, true)
      assert.truthy(report:match('### /path/to/test%.md'))
      assert.truthy(report:match('Fixed 1 shots missing dates'))
    end)

    it('should show "No issues found" when no details', function()
      local results = {
        files_checked = 5,
        dates_fixed = 0,
        history_created = 0,
        details = {}
      }

      local report = audit_runner.generate_report(results, false)
      assert.truthy(report:match('No issues found'))
    end)

    it('should indicate mode in report', function()
      local results = { files_checked = 0, dates_fixed = 0, history_created = 0, details = {} }

      local report_fix = audit_runner.generate_report(results, true)
      assert.truthy(report_fix:match('Mode:%*%* Fix'))

      local report_report = audit_runner.generate_report(results, false)
      assert.truthy(report_report:match('Mode:%*%* Report only'))
    end)
  end)
end)

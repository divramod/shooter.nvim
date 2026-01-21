-- Test suite for shooter.analytics module
local analytics = require('shooter.analytics')

describe('analytics module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(analytics.generate_report)
      assert.is_function(analytics.show)
      assert.is_function(analytics.show_global)
      assert.is_function(analytics.show_project)
    end)
  end)

  describe('generate_report', function()
    it('returns a table of lines', function()
      local lines = analytics.generate_report(nil)
      assert.is_table(lines)
      assert.is_true(#lines > 0)
    end)

    it('includes header in report', function()
      local lines = analytics.generate_report(nil)
      assert.is_true(lines[1]:match('# Shooter Analytics') ~= nil)
    end)

    it('includes shot counts section', function()
      local lines = analytics.generate_report(nil)
      local found = false
      for _, line in ipairs(lines) do
        if line:match('## Shot Counts') then found = true; break end
      end
      assert.is_true(found)
    end)

    it('includes averages section', function()
      local lines = analytics.generate_report(nil)
      local found = false
      for _, line in ipairs(lines) do
        if line:match('## Averages') then found = true; break end
      end
      assert.is_true(found)
    end)

    it('includes file rankings section', function()
      local lines = analytics.generate_report(nil)
      local found = false
      for _, line in ipairs(lines) do
        if line:match('## File Rankings') then found = true; break end
      end
      assert.is_true(found)
    end)

    it('includes timestamp', function()
      local lines = analytics.generate_report(nil)
      local found = false
      for _, line in ipairs(lines) do
        if line:match('%*Generated:') then found = true; break end
      end
      assert.is_true(found)
    end)

    it('filters by project when specified', function()
      local lines = analytics.generate_report('nonexistent-project-xyz')
      assert.is_true(lines[1]:match('nonexistent%-project%-xyz') ~= nil)
    end)
  end)
end)

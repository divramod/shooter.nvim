-- Tests for session/sort.lua
local sort = require('shooter.session.sort')
local defaults = require('shooter.session.defaults')

describe('session.sort', function()
  before_each(function()
    sort.clear_cache()
  end)

  describe('get_enabled_criteria', function()
    it('should return enabled criteria sorted by priority', function()
      local sort_config = {
        filename = { enabled = true, priority = 2, ascending = true },
        modified = { enabled = true, priority = 1, ascending = false },
        created = { enabled = false, priority = 0, ascending = true },
      }
      local criteria = sort.get_enabled_criteria(sort_config)
      assert.equals(2, #criteria)
      assert.equals('modified', criteria[1].name)
      assert.equals('filename', criteria[2].name)
    end)

    it('should exclude disabled criteria', function()
      local sort_config = {
        filename = { enabled = false, priority = 1, ascending = true },
        modified = { enabled = false, priority = 2, ascending = false },
      }
      local criteria = sort.get_enabled_criteria(sort_config)
      assert.equals(0, #criteria)
    end)

    it('should exclude priority 0 criteria', function()
      local sort_config = {
        filename = { enabled = true, priority = 0, ascending = true },
      }
      local criteria = sort.get_enabled_criteria(sort_config)
      assert.equals(0, #criteria)
    end)
  end)

  describe('get_sort_status', function()
    it('should return default for no enabled criteria', function()
      local session = defaults.create_session('test')
      -- Disable all
      for _, c in ipairs(defaults.get_sort_criteria()) do
        session.sortBy[c].enabled = false
      end
      local status = sort.get_sort_status(session)
      assert.equals('default', status)
    end)

    it('should show enabled criteria with direction', function()
      local session = defaults.create_session('test')
      -- Default has filename enabled
      local status = sort.get_sort_status(session)
      assert.matches('filename', status)
    end)

    it('should show desc for descending', function()
      local session = defaults.create_session('test')
      session.sortBy.modified.enabled = true
      session.sortBy.modified.priority = 2
      session.sortBy.modified.ascending = false
      local status = sort.get_sort_status(session)
      assert.matches('modified desc', status)
    end)
  end)

  describe('sort_files', function()
    -- Create mock files for testing
    local function make_files()
      return {
        { path = '/repo/plans/prompts/b-file.md', display = 'b-file.md' },
        { path = '/repo/plans/prompts/a-file.md', display = 'a-file.md' },
        { path = '/repo/plans/prompts/c-file.md', display = 'c-file.md' },
      }
    end

    it('should return files unchanged if no sorting enabled', function()
      local session = defaults.create_session('test')
      for _, c in ipairs(defaults.get_sort_criteria()) do
        session.sortBy[c].enabled = false
      end
      local files = make_files()
      local sorted = sort.sort_files(files, session)
      assert.equals('b-file.md', sorted[1].display)
    end)

    it('should sort by filename ascending', function()
      local session = defaults.create_session('test')
      -- filename is enabled by default with priority 1, ascending true
      local files = make_files()
      local sorted = sort.sort_files(files, session)
      assert.equals('a-file.md', sorted[1].display)
      assert.equals('b-file.md', sorted[2].display)
      assert.equals('c-file.md', sorted[3].display)
    end)

    it('should sort by filename descending', function()
      local session = defaults.create_session('test')
      session.sortBy.filename.ascending = false
      local files = make_files()
      local sorted = sort.sort_files(files, session)
      assert.equals('c-file.md', sorted[1].display)
      assert.equals('a-file.md', sorted[3].display)
    end)
  end)

  describe('build_comparator', function()
    it('should handle multi-criteria comparison', function()
      local criteria = {
        { name = 'projectname', ascending = true },
        { name = 'filename', ascending = true },
      }
      local cmp = sort.build_comparator(criteria)
      assert.is_function(cmp)
    end)
  end)
end)

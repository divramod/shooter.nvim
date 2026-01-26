-- Tests for session/defaults.lua
local defaults = require('shooter.session.defaults')

describe('session.defaults', function()
  describe('DEFAULT', function()
    it('should have name set to init', function()
      assert.equals('init', defaults.DEFAULT.name)
    end)

    it('should have filters.projects structure', function()
      assert.is_true(defaults.DEFAULT.filters.projects.rootProject)
      assert.same({}, defaults.DEFAULT.filters.projects.subProjects)
    end)

    it('should have all folder toggles with prompts as only enabled', function()
      local folders = defaults.DEFAULT.filters.folders
      assert.is_false(folders.archive)
      assert.is_false(folders.backlog)
      assert.is_false(folders.done)
      assert.is_false(folders.reqs)
      assert.is_false(folders.wait)
      assert.is_true(folders.prompts)
    end)

    it('should have sortBy with filename enabled', function()
      assert.is_true(defaults.DEFAULT.sortBy.filename.enabled)
      assert.equals(1, defaults.DEFAULT.sortBy.filename.priority)
    end)
  end)

  describe('create_session', function()
    it('should create session with given name', function()
      local session = defaults.create_session('test-session')
      assert.equals('test-session', session.name)
    end)

    it('should create independent copy of DEFAULT', function()
      local session = defaults.create_session('test')
      session.filters.folders.archive = true
      assert.is_false(defaults.DEFAULT.filters.folders.archive)
    end)

    it('should use init as default name', function()
      local session = defaults.create_session()
      assert.equals('init', session.name)
    end)
  end)

  describe('validate_session', function()
    it('should return DEFAULT for nil input', function()
      local session = defaults.validate_session(nil)
      assert.equals('init', session.name)
    end)

    it('should fill missing filters', function()
      local session = defaults.validate_session({ name = 'test' })
      assert.is_not_nil(session.filters)
      assert.is_not_nil(session.filters.projects)
      assert.is_not_nil(session.filters.folders)
    end)

    it('should preserve existing values', function()
      local session = defaults.validate_session({
        name = 'custom',
        filters = { folders = { archive = true } },
      })
      assert.equals('custom', session.name)
      assert.is_true(session.filters.folders.archive)
    end)

    it('should fill missing folder keys', function()
      local session = defaults.validate_session({
        name = 'test',
        filters = { folders = { archive = true } },
      })
      assert.is_false(session.filters.folders.backlog)
      assert.is_true(session.filters.folders.prompts)
    end)
  end)

  describe('reset_folders', function()
    it('should return default folder config', function()
      local folders = defaults.reset_folders()
      assert.is_false(folders.archive)
      assert.is_true(folders.prompts)
    end)

    it('should return independent copy', function()
      local folders = defaults.reset_folders()
      folders.archive = true
      local folders2 = defaults.reset_folders()
      assert.is_false(folders2.archive)
    end)
  end)

  describe('get_folder_names', function()
    it('should return all 6 folder names', function()
      local names = defaults.get_folder_names()
      assert.equals(6, #names)
      assert.is_true(vim.tbl_contains(names, 'archive'))
      assert.is_true(vim.tbl_contains(names, 'prompts'))
    end)
  end)

  describe('get_sort_criteria', function()
    it('should return all 6 sort criteria', function()
      local criteria = defaults.get_sort_criteria()
      assert.equals(6, #criteria)
      assert.is_true(vim.tbl_contains(criteria, 'filename'))
      assert.is_true(vim.tbl_contains(criteria, 'modified'))
    end)
  end)
end)

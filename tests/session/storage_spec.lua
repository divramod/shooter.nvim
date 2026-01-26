-- Tests for session/storage.lua
local storage = require('shooter.session.storage')
local defaults = require('shooter.session.defaults')

describe('session.storage', function()
  describe('get_repo_slug', function()
    it('should extract owner/repo from path', function()
      local slug = storage.get_repo_slug('/Users/mod/cod/shooter.nvim')
      assert.equals('cod/shooter.nvim', slug)
    end)

    it('should handle single component path', function()
      local slug = storage.get_repo_slug('/root')
      assert.equals('root', slug)
    end)

    it('should return unknown for nil', function()
      local slug = storage.get_repo_slug(nil)
      assert.equals('unknown', slug)
    end)
  end)

  describe('get_sessions_dir', function()
    it('should return path with sanitized repo slug', function()
      local dir = storage.get_sessions_dir('owner/repo')
      assert.matches('shooter%.nvim/sessions/owner_repo$', dir)
    end)
  end)

  describe('YAML serialization', function()
    local test_slug = 'test_yaml_serialization'

    before_each(function()
      -- Clean up before each test
      local sessions_dir = storage.get_sessions_dir(test_slug)
      vim.fn.delete(sessions_dir, 'rf')
    end)

    after_each(function()
      -- Clean up after each test
      local sessions_dir = storage.get_sessions_dir(test_slug)
      vim.fn.delete(sessions_dir, 'rf')
    end)

    it('should write and read session correctly', function()
      local session = defaults.create_session('test-session')
      session.filters.folders.archive = true
      session.filters.projects.subProjects = { 'project-a', 'project-b' }

      -- Write directly to test location
      local sessions_dir = storage.get_sessions_dir(test_slug)
      vim.fn.mkdir(sessions_dir, 'p')
      storage.write_session(test_slug, session)

      -- Read back
      local loaded = storage.read_session(test_slug, 'test-session')
      assert.is_not_nil(loaded)
      assert.equals('test-session', loaded.name)
      assert.is_true(loaded.filters.folders.archive)
      assert.equals(2, #loaded.filters.projects.subProjects)
    end)

    it('should list sessions in directory', function()
      local sessions_dir = storage.get_sessions_dir(test_slug)
      vim.fn.mkdir(sessions_dir, 'p')

      -- Create some session files
      storage.write_session(test_slug, defaults.create_session('session-a'))
      storage.write_session(test_slug, defaults.create_session('session-b'))

      local sessions = storage.list_sessions(test_slug)
      assert.equals(2, #sessions)
      assert.is_true(vim.tbl_contains(sessions, 'session-a'))
      assert.is_true(vim.tbl_contains(sessions, 'session-b'))
    end)

    it('should delete session', function()
      local sessions_dir = storage.get_sessions_dir(test_slug)
      vim.fn.mkdir(sessions_dir, 'p')

      storage.write_session(test_slug, defaults.create_session('to-delete'))
      assert.is_not_nil(storage.read_session(test_slug, 'to-delete'))

      storage.delete_session(test_slug, 'to-delete')
      assert.is_nil(storage.read_session(test_slug, 'to-delete'))
    end)

    it('should rename session', function()
      local sessions_dir = storage.get_sessions_dir(test_slug)
      vim.fn.mkdir(sessions_dir, 'p')

      storage.write_session(test_slug, defaults.create_session('old-name'))
      storage.rename_session(test_slug, 'old-name', 'new-name')

      assert.is_nil(storage.read_session(test_slug, 'old-name'))
      local renamed = storage.read_session(test_slug, 'new-name')
      assert.is_not_nil(renamed)
      assert.equals('new-name', renamed.name)
    end)
  end)

  describe('ensure_init_session', function()
    local test_slug = 'test_ensure_init'

    after_each(function()
      local dir = storage.get_sessions_dir(test_slug)
      vim.fn.delete(dir, 'rf')
    end)

    it('should create init session if not exists', function()
      local session = storage.ensure_init_session(test_slug)
      assert.equals('init', session.name)

      -- Verify it was written
      local loaded = storage.read_session(test_slug, 'init')
      assert.is_not_nil(loaded)
    end)

    it('should return existing init session', function()
      -- Create custom init
      local custom = defaults.create_session('init')
      custom.filters.folders.archive = true
      storage.write_session(test_slug, custom)

      -- Ensure should return existing
      local session = storage.ensure_init_session(test_slug)
      assert.is_true(session.filters.folders.archive)
    end)
  end)
end)

-- Tests for session/filter.lua
local filter = require('shooter.session.filter')
local defaults = require('shooter.session.defaults')

describe('session.filter', function()
  describe('detect_file_folder', function()
    it('should detect archive folder', function()
      local folder = filter.detect_file_folder('/repo/plans/prompts/archive/file.md')
      assert.equals('archive', folder)
    end)

    it('should detect backlog folder', function()
      local folder = filter.detect_file_folder('/repo/plans/prompts/backlog/task.md')
      assert.equals('backlog', folder)
    end)

    it('should detect prompts (root) for direct files', function()
      local folder = filter.detect_file_folder('/repo/plans/prompts/feature.md')
      assert.equals('prompts', folder)
    end)

    it('should handle nested paths', function()
      local folder = filter.detect_file_folder('/repo/plans/prompts/done/2024/file.md')
      assert.equals('done', folder)
    end)

    it('should handle project paths', function()
      local folder = filter.detect_file_folder('/repo/projects/myapp/plans/prompts/archive/old.md')
      assert.equals('archive', folder)
    end)
  end)

  describe('detect_file_project', function()
    local git_root = '/Users/mod/cod/shooter.nvim'

    it('should return nil for root project files', function()
      local project = filter.detect_file_project(git_root .. '/plans/prompts/file.md', git_root)
      assert.is_nil(project)
    end)

    it('should detect subproject name', function()
      local project = filter.detect_file_project(git_root .. '/projects/myapp/plans/prompts/file.md', git_root)
      assert.equals('myapp', project)
    end)

    it('should return nil if no git_root', function()
      local project = filter.detect_file_project('/some/path/file.md', nil)
      assert.is_nil(project)
    end)
  end)

  describe('apply_folder_filter', function()
    local files = {
      { path = '/repo/plans/prompts/file.md', display = 'file.md' },
      { path = '/repo/plans/prompts/archive/old.md', display = 'archive/old.md' },
      { path = '/repo/plans/prompts/backlog/todo.md', display = 'backlog/todo.md' },
    }

    it('should filter to only enabled folders', function()
      local folders = { prompts = true, archive = false, backlog = false }
      local result = filter.apply_folder_filter(files, folders)
      assert.equals(1, #result)
      assert.equals('file.md', result[1].display)
    end)

    it('should include multiple enabled folders', function()
      local folders = { prompts = true, archive = true, backlog = false }
      local result = filter.apply_folder_filter(files, folders)
      assert.equals(2, #result)
    end)

    it('should return empty if no folders enabled', function()
      local folders = { prompts = false, archive = false, backlog = false }
      local result = filter.apply_folder_filter(files, folders)
      assert.equals(0, #result)
    end)
  end)

  describe('apply_project_filter', function()
    local git_root = '/repo'
    local files = {
      { path = '/repo/plans/prompts/root.md' },
      { path = '/repo/projects/app-a/plans/prompts/a.md' },
      { path = '/repo/projects/app-b/plans/prompts/b.md' },
    }

    it('should filter to root only', function()
      local projects = { rootProject = true, subProjects = {} }
      local result = filter.apply_project_filter(files, projects, git_root)
      assert.equals(1, #result)
      assert.matches('root%.md', result[1].path)
    end)

    it('should filter to specified subprojects', function()
      local projects = { rootProject = false, subProjects = { 'app-a' } }
      local result = filter.apply_project_filter(files, projects, git_root)
      assert.equals(1, #result)
      assert.matches('app%-a', result[1].path)
    end)

    it('should include root and specified subprojects', function()
      local projects = { rootProject = true, subProjects = { 'app-b' } }
      local result = filter.apply_project_filter(files, projects, git_root)
      assert.equals(2, #result)
    end)

    it('should return empty if nothing enabled', function()
      local projects = { rootProject = false, subProjects = {} }
      local result = filter.apply_project_filter(files, projects, git_root)
      assert.equals(0, #result)
    end)
  end)

  describe('get_active_folders', function()
    it('should return list of enabled folders', function()
      local session = defaults.create_session('test')
      session.filters.folders.archive = true
      local active = filter.get_active_folders(session)
      assert.equals(2, #active) -- prompts and archive
    end)
  end)

  describe('get_filter_status', function()
    it('should return single folder name', function()
      local session = defaults.create_session('test')
      -- Only prompts is enabled by default
      local status = filter.get_filter_status(session)
      assert.equals('prompts', status)
    end)

    it('should return combined names for multiple', function()
      local session = defaults.create_session('test')
      session.filters.folders.archive = true
      local status = filter.get_filter_status(session)
      assert.matches('prompts', status)
      assert.matches('archive', status)
    end)

    it('should return none if nothing enabled', function()
      local session = defaults.create_session('test')
      session.filters.folders.prompts = false
      local status = filter.get_filter_status(session)
      assert.equals('none', status)
    end)
  end)
end)

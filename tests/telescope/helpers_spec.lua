-- Test suite for shooter.telescope.helpers module.
-- Telescope itself isn't installed in CI, so stub action_state before
-- requiring helpers. The stub satisfies the top-level `require` and the
-- per-function tests inject their own action_state stand-ins where needed.

local function stub_telescope()
  package.loaded['telescope.actions'] = {
    toggle_selection = function(_) end,
  }
  package.loaded['telescope.actions.state'] = {
    get_current_picker = function(_) return nil end,
  }
end

stub_telescope()
package.loaded['shooter.telescope.helpers'] = nil
local helpers = require('shooter.telescope.helpers')

-- Filesystem fixture helpers ------------------------------------------------

local function mktempdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  return dir
end

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local f = assert(io.open(path, 'w'))
  f:write(content)
  f:close()
end

local function rmrf(path)
  vim.fn.delete(path, 'rf')
end

-- Module mock helpers -------------------------------------------------------

local saved_modules = {}

local function mock_module(name, replacement)
  saved_modules[name] = saved_modules[name] or package.loaded[name]
  package.loaded[name] = replacement
end

local function restore_modules()
  for name, original in pairs(saved_modules) do
    package.loaded[name] = original
  end
  saved_modules = {}
end

describe('telescope helpers', function()
  describe('module structure', function()
    it('exports the expected public surface', function()
      assert.is_function(helpers.find_open_shots)
      assert.is_function(helpers.make_shot_entry)
      assert.is_function(helpers.get_repo_prompt_files)
      assert.is_function(helpers.get_all_repo_shots)
      assert.is_function(helpers.read_lines)
      assert.is_function(helpers.get_target_file)
      assert.is_function(helpers.get_file_mtime)
      assert.is_function(helpers.clear_selection)
      assert.is_function(helpers.save_selection_state)
      assert.is_function(helpers.restore_selection_state)
      assert.is_function(helpers.get_prompt_files)
      assert.is_function(helpers.get_all_repos_prompt_files)
      assert.is_function(helpers.get_bullet_files)
      assert.is_table(helpers.persistent_state)
    end)
  end)

  describe('get_file_mtime', function()
    it('returns 0 for missing files', function()
      assert.are.equal(0, helpers.get_file_mtime('/no/such/path/9d3f1.txt'))
    end)

    it('returns the mtime in seconds for an existing file', function()
      local dir = mktempdir()
      local path = dir .. '/file.txt'
      write_file(path, 'x')
      local mt = helpers.get_file_mtime(path)
      assert.is_true(mt > 0)
      assert.is_true(mt <= os.time())
      rmrf(dir)
    end)
  end)

  describe('clear_selection', function()
    it('clears state for a single file', function()
      helpers.persistent_state['/a/b.md'] = { selections = {1}, cursor_row = 0 }
      helpers.persistent_state['/c/d.md'] = { selections = {2}, cursor_row = 1 }
      helpers.clear_selection('/a/b.md')
      assert.is_nil(helpers.persistent_state['/a/b.md'])
      assert.is_not_nil(helpers.persistent_state['/c/d.md'])
      helpers.clear_selection('/c/d.md')
    end)

    it('clears all state when called with no arg', function()
      helpers.persistent_state['/x.md'] = { selections = {} }
      helpers.persistent_state['/y.md'] = { selections = {} }
      helpers.clear_selection()
      assert.are.equal(0, vim.tbl_count(helpers.persistent_state))
    end)
  end)

  describe('find_open_shots', function()
    it('finds open shots in lines', function()
      local lines = {
        '# Title', '',
        '## shot 1', 'Shot 1 content', '',
        '## x shot 2', 'Shot 2 executed', '',
        '## shot 3', 'Shot 3 content',
      }
      local shots = helpers.find_open_shots(lines)
      assert.are.equal(2, #shots)
      assert.are.equal(3, shots[1].header_line)
      assert.are.equal(9, shots[2].header_line)
    end)

    it('returns empty table when no open shots', function()
      local lines = { '# Title', '', '## x shot 1', 'Executed' }
      assert.are.equal(0, #helpers.find_open_shots(lines))
    end)

    it('trims trailing blank lines from end_line', function()
      local lines = { '## shot 1', 'body', '', '', '## shot 2', 'body2', '' }
      local shots = helpers.find_open_shots(lines)
      assert.are.equal(2, #shots)
      assert.are.equal(2, shots[1].end_line)
      assert.are.equal(6, shots[2].end_line)
    end)

    it('handles file with only one open shot to EOF', function()
      local lines = { '## shot 1', 'a', 'b' }
      local shots = helpers.find_open_shots(lines)
      assert.are.equal(1, #shots)
      assert.are.equal(3, shots[1].end_line)
    end)
  end)

  describe('make_shot_entry', function()
    it('creates entry without file prefix by default', function()
      local lines = { '## shot 5', 'Content here' }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/p/file.md', false, false)
      assert.is_truthy(entry.display:match('^Shot 5:'))
      assert.is_falsy(entry.display:match('%[file%]'))
      assert.are.equal(1, entry.header_line)
      assert.are.equal('/p/file.md', entry.target_file)
    end)

    it('creates entry with file prefix when show_file is true', function()
      local lines = { '## shot 5', 'Content here' }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/p/myfile.md', false, true)
      assert.is_truthy(entry.display:match('%[myfile%]'))
      assert.is_truthy(entry.display:match('Shot 5:'))
    end)

    it('truncates preview > 60 chars', function()
      local long = string.rep('x', 80)
      local lines = { '## shot 1', long }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/p/f.md', false, false)
      assert.is_truthy(entry.display:match('%.%.%.$'))
      -- "Shot 1: " (8) + 60 chars + "..." (3) caps the visible payload
      assert.is_true(#entry.display <= 8 + 60 + 3 + 5)
    end)

    it('uses header description when present', function()
      mock_module('shooter.core.shots', {
        parse_shot_header_text = function(_) return 'header desc' end,
      })
      local lines = { '## shot 9 header desc', 'body' }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/p/f.md', false, false)
      assert.is_truthy(entry.display:match('header desc'))
      restore_modules()
    end)

    it('falls back to body preview when header has no description', function()
      mock_module('shooter.core.shots', {
        parse_shot_header_text = function(_) return nil end,
      })
      local lines = { '## shot 9', 'first body', '', 'second body' }
      local shot = { header_line = 1, start_line = 1, end_line = 4 }
      local entry = helpers.make_shot_entry(shot, lines, '/p/f.md', false, false)
      assert.is_truthy(entry.display:match('first body'))
      restore_modules()
    end)

    it('handles missing shot number gracefully', function()
      local lines = { '## shot ', 'body' }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/p/f.md', false, false)
      assert.is_truthy(entry.display:match('^Shot %?:'))
    end)
  end)

  describe('read_lines', function()
    it('reads from disk when not current file', function()
      local dir = mktempdir()
      local path = dir .. '/x.md'
      write_file(path, 'line1\nline2\nline3')
      local lines = helpers.read_lines(path, false)
      -- helpers.read_lines uses gmatch('[^\n]*') which yields empty strings
      -- between newlines; non-empty entries should still appear in order.
      local non_empty = {}
      for _, l in ipairs(lines) do
        if l ~= '' then table.insert(non_empty, l) end
      end
      assert.are.equal('line1', non_empty[1])
      assert.are.equal('line2', non_empty[2])
      assert.are.equal('line3', non_empty[3])
      rmrf(dir)
    end)

    it('returns nil for missing file when not current', function()
      local lines = helpers.read_lines('/no/such/file.md', false)
      assert.is_nil(lines)
    end)

    it('reads from current buffer when is_current is true', function()
      local original = vim.api.nvim_buf_get_lines
      vim.api.nvim_buf_get_lines = function(_, _, _, _) return { 'a', 'b' } end
      local lines = helpers.read_lines('ignored', true)
      assert.are.equal('a', lines[1])
      assert.are.equal('b', lines[2])
      vim.api.nvim_buf_get_lines = original
    end)
  end)

  describe('get_target_file', function()
    it('returns current file when in prompts folder', function()
      mock_module('shooter.core.files', {
        is_in_prompts_folder = function(p) return p == '/repo/docs/shotfiles/x.md' end,
        find_last_file = function() return '/repo/docs/shotfiles/last.md' end,
      })
      local original_expand = vim.fn.expand
      vim.fn.expand = function(_) return '/repo/docs/shotfiles/x.md' end
      local target, is_current = helpers.get_target_file()
      assert.are.equal('/repo/docs/shotfiles/x.md', target)
      assert.is_true(is_current)
      vim.fn.expand = original_expand
      restore_modules()
    end)

    it('falls back to last edited when not in prompts folder', function()
      mock_module('shooter.core.files', {
        is_in_prompts_folder = function(_) return false end,
        find_last_file = function() return '/last.md' end,
      })
      local original_expand = vim.fn.expand
      vim.fn.expand = function(_) return '/elsewhere/file.md' end
      local target, is_current = helpers.get_target_file()
      assert.are.equal('/last.md', target)
      assert.is_false(is_current)
      vim.fn.expand = original_expand
      restore_modules()
    end)
  end)

  describe('get_repo_prompt_files', function()
    it('returns empty when no git root', function()
      mock_module('shooter.core.files', { get_git_root = function() return nil end })
      mock_module('shooter.utils', { dir_exists = function(_) return false end })
      assert.are.equal(0, #helpers.get_repo_prompt_files())
      restore_modules()
    end)

    it('returns empty when prompts dir missing', function()
      mock_module('shooter.core.files', { get_git_root = function() return '/no/repo' end })
      mock_module('shooter.utils', { dir_exists = function(_) return false end })
      assert.are.equal(0, #helpers.get_repo_prompt_files())
      restore_modules()
    end)

    it('returns markdown files from docs/shotfiles', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/docs/shotfiles/sub', 'p')
      write_file(dir .. '/docs/shotfiles/a.md', '## shot 1')
      write_file(dir .. '/docs/shotfiles/sub/b.md', '## shot 1')
      mock_module('shooter.core.files', { get_git_root = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      local files = helpers.get_repo_prompt_files()
      assert.is_true(#files >= 2)
      restore_modules()
      rmrf(dir)
    end)
  end)

  describe('get_all_repo_shots', function()
    it('aggregates open shots across all prompt files', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/docs/shotfiles', 'p')
      write_file(dir .. '/docs/shotfiles/a.md', '# A\n\n## shot 1\nfoo\n')
      write_file(dir .. '/docs/shotfiles/b.md', '# B\n\n## shot 1\nbar\n## x shot 2\ndone\n')
      mock_module('shooter.core.files', { get_git_root = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      mock_module('shooter.core.shots', {
        parse_shot_header_text = function(_) return nil end,
      })
      local shots = helpers.get_all_repo_shots()
      assert.is_true(#shots >= 2)
      for _, s in ipairs(shots) do
        assert.is_string(s.display)
        assert.is_string(s.target_file)
      end
      restore_modules()
      rmrf(dir)
    end)
  end)

  describe('get_prompt_files', function()
    it('handles legacy (folder_filter, project) calling convention', function()
      mock_module('shooter.core.files', {
        get_prompts_dir = function(_) return '/no/prompts' end,
      })
      mock_module('shooter.core.project', {})
      mock_module('shooter.utils', { dir_exists = function(_) return false end })
      local results = helpers.get_prompt_files('archive', 'proj')
      assert.is_table(results)
      restore_modules()
    end)

    it('handles new opts calling convention', function()
      mock_module('shooter.core.files', {
        get_prompts_dir = function(_) return '/no/prompts' end,
      })
      mock_module('shooter.core.project', {})
      mock_module('shooter.utils', { dir_exists = function(_) return false end })
      local results = helpers.get_prompt_files({ folder_filter = 'archive', project = 'p' })
      assert.is_table(results)
      restore_modules()
    end)

    it('lists files from a single project under prompts dir', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/archive', 'p')
      write_file(dir .. '/archive/old.md', '## shot 1')
      write_file(dir .. '/active.md', '## shot 1')
      mock_module('shooter.core.files', { get_prompts_dir = function(_) return dir end })
      mock_module('shooter.core.project', {})
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      local results = helpers.get_prompt_files({ folder_filter = 'archive' })
      assert.is_true(#results >= 1)
      local found_archive = false
      for _, r in ipairs(results) do
        if r.path:match('archive/old.md') then found_archive = true end
      end
      assert.is_true(found_archive)
      restore_modules()
      rmrf(dir)
    end)

    it('include_all_projects walks root + plans + projects', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/docs/shotfiles', 'p')
      vim.fn.mkdir(dir .. '/docs/plans/0001-test', 'p')
      vim.fn.mkdir(dir .. '/projects/p1/docs/shotfiles', 'p')
      write_file(dir .. '/docs/shotfiles/root.md', '## shot 1')
      write_file(dir .. '/docs/plans/metaplan.md', '# meta')
      write_file(dir .. '/docs/plans/0001-test/idea.md', '# idea')
      write_file(dir .. '/docs/plans/0001-test/spec.md', '# spec')
      write_file(dir .. '/projects/p1/docs/shotfiles/proj.md', '## shot 1')

      mock_module('shooter.core.files', { get_git_root = function() return dir end })
      mock_module('shooter.core.project', {})
      mock_module('shooter.tools.git_worktree', { get_main_worktree = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
        cwd = function() return dir end,
      })
      mock_module('shooter.config', { get = function(_) return {} end })

      local results = helpers.get_prompt_files({ include_all_projects = true })
      local has_root, has_meta, has_idea, has_spec, has_proj = false, false, false, false, false
      for _, r in ipairs(results) do
        if r.display == 'root.md' then has_root = true end
        if r.display == 'docs/plans/metaplan.md' then has_meta = true end
        if r.display:match('idea.md$') then has_idea = true end
        if r.display:match('spec.md$') then has_spec = true end
        if r.display:match('^p1/proj.md$') then has_proj = true end
      end
      assert.is_true(has_root)
      assert.is_true(has_meta)
      assert.is_true(has_idea)
      assert.is_true(has_spec)
      assert.is_true(has_proj)
      restore_modules()
      rmrf(dir)
    end)

    it('include_all_projects honors projects.exclude_folders', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/docs/shotfiles', 'p')
      vim.fn.mkdir(dir .. '/projects/p1/docs/shotfiles', 'p')
      vim.fn.mkdir(dir .. '/projects/excluded/docs/shotfiles', 'p')
      write_file(dir .. '/projects/p1/docs/shotfiles/p1.md', '## shot 1')
      write_file(dir .. '/projects/excluded/docs/shotfiles/x.md', '## shot 1')

      mock_module('shooter.core.files', { get_git_root = function() return dir end })
      mock_module('shooter.core.project', {})
      mock_module('shooter.tools.git_worktree', { get_main_worktree = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
        cwd = function() return dir end,
      })
      mock_module('shooter.config', {
        get = function(key)
          if key == 'projects.exclude_folders' then return { 'excluded' } end
          return nil
        end,
      })

      local results = helpers.get_prompt_files({ include_all_projects = true })
      local has_excluded = false
      for _, r in ipairs(results) do
        if r.display:match('excluded') then has_excluded = true end
      end
      assert.is_false(has_excluded)
      restore_modules()
      rmrf(dir)
    end)

    it('projects= list filters to specified projects', function()
      mock_module('shooter.core.files', { get_prompts_dir = function(_) return '/no/d' end })
      mock_module('shooter.core.project', {})
      mock_module('shooter.utils', { dir_exists = function(_) return false end })
      local results = helpers.get_prompt_files({ projects = { 'a', 'b' } })
      assert.is_table(results)
      restore_modules()
    end)

    it('sort_by_mtime reorders results', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir, 'p')
      write_file(dir .. '/a.md', 'a')
      vim.loop.sleep(10)
      write_file(dir .. '/b.md', 'b')
      mock_module('shooter.core.files', { get_prompts_dir = function(_) return dir end })
      mock_module('shooter.core.project', {})
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      local results = helpers.get_prompt_files({ sort_by_mtime = true })
      assert.is_true(#results >= 1)
      restore_modules()
      rmrf(dir)
    end)
  end)

  describe('get_all_repos_prompt_files', function()
    it('returns empty when no repos configured', function()
      mock_module('shooter.config', { get = function(_) return {} end })
      mock_module('shooter.utils', {
        dir_exists = function(_) return false end,
        expand_path = function(p) return p end,
      })
      local results = helpers.get_all_repos_prompt_files({})
      assert.are.equal(0, #results)
      restore_modules()
    end)

    it('handles legacy folder_filter string', function()
      mock_module('shooter.config', { get = function(_) return {} end })
      mock_module('shooter.utils', {
        dir_exists = function(_) return false end,
        expand_path = function(p) return p end,
      })
      local results = helpers.get_all_repos_prompt_files('archive')
      assert.is_table(results)
      restore_modules()
    end)

    it('walks direct repo paths and search dirs', function()
      local repos = mktempdir()
      vim.fn.mkdir(repos .. '/r1/.git', 'p')
      vim.fn.mkdir(repos .. '/r1/docs/shotfiles', 'p')
      write_file(repos .. '/r1/docs/shotfiles/r1file.md', '## shot 1')

      mock_module('shooter.config', {
        get = function(key)
          if key == 'repos.direct_paths' then return { repos .. '/r1' } end
          if key == 'repos.search_dirs' then return {} end
          return nil
        end,
      })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
        expand_path = function(p) return p end,
      })

      local results = helpers.get_all_repos_prompt_files({})
      local found = false
      for _, r in ipairs(results) do
        if r.display:match('^r1/r1file.md$') then found = true end
      end
      assert.is_true(found)
      restore_modules()
      rmrf(repos)
    end)

    it('sort_by_mtime branch executes', function()
      mock_module('shooter.config', { get = function(_) return {} end })
      mock_module('shooter.utils', {
        dir_exists = function(_) return false end,
        expand_path = function(p) return p end,
      })
      local results = helpers.get_all_repos_prompt_files({ sort_by_mtime = true })
      assert.is_table(results)
      restore_modules()
    end)
  end)

  describe('get_bullet_files', function()
    it('returns empty when bullets root missing', function()
      mock_module('shooter.core.ext_config', { bullets_dir = function() return '/no/bullets' end })
      mock_module('shooter.utils', { dir_exists = function(_) return false end })
      assert.are.equal(0, #helpers.get_bullet_files({}))
      restore_modules()
    end)

    it('returns empty for scope=file with missing args', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir, 'p')
      mock_module('shooter.core.ext_config', { bullets_dir = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      assert.are.equal(0, #helpers.get_bullet_files({ scope = 'file' }))
      assert.are.equal(0,
        #helpers.get_bullet_files({ scope = 'file', repo_slug = 'r' }))
      restore_modules()
      rmrf(dir)
    end)

    it('returns matching bullets for scope=file', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/myrepo', 'p')
      write_file(dir .. '/myrepo/feats_001.md', 'b1')
      write_file(dir .. '/myrepo/feats_002.md', 'b2')
      write_file(dir .. '/myrepo/other_001.md', 'other')

      mock_module('shooter.core.ext_config', { bullets_dir = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      local results = helpers.get_bullet_files({
        scope = 'file', repo_slug = 'myrepo', shotfile_basename = 'feats',
      })
      assert.are.equal(2, #results)
      restore_modules()
      rmrf(dir)
    end)

    it('returns repo bullets for scope=repo', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/myrepo', 'p')
      write_file(dir .. '/myrepo/a_1.md', 'a')
      write_file(dir .. '/myrepo/b_1.md', 'b')

      mock_module('shooter.core.ext_config', { bullets_dir = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      local results = helpers.get_bullet_files({ scope = 'repo', repo_slug = 'myrepo' })
      assert.are.equal(2, #results)
      restore_modules()
      rmrf(dir)
    end)

    it('returns empty when scope=repo has no slug', function()
      mock_module('shooter.core.ext_config', { bullets_dir = function() return '/tmp' end })
      mock_module('shooter.utils', { dir_exists = function(_) return true end })
      local results = helpers.get_bullet_files({ scope = 'repo' })
      assert.are.equal(0, #results)
      restore_modules()
    end)

    it('walks all repos for default scope', function()
      local dir = mktempdir()
      vim.fn.mkdir(dir .. '/r1', 'p')
      vim.fn.mkdir(dir .. '/r2', 'p')
      write_file(dir .. '/r1/x_1.md', 'x')
      write_file(dir .. '/r2/y_1.md', 'y')

      mock_module('shooter.core.ext_config', { bullets_dir = function() return dir end })
      mock_module('shooter.utils', {
        dir_exists = function(p) return vim.fn.isdirectory(p) == 1 end,
      })
      local results = helpers.get_bullet_files({})
      assert.is_true(#results >= 2)
      restore_modules()
      rmrf(dir)
    end)
  end)

  describe('save_selection_state / restore_selection_state', function()
    -- helpers cached `local action_state = require('telescope.actions.state')`
    -- at module load. Mutate that same table in-place so helpers picks up
    -- our fakes; reset between tests via the stub_action_state helper.
    local function stub_action_state(fn)
      package.loaded['telescope.actions.state'].get_current_picker = fn
    end
    local function stub_actions(fn)
      package.loaded['telescope.actions'].toggle_selection = fn
    end

    it('save_selection_state captures multi-selection and cursor', function()
      local fake_picker = {
        get_multi_selection = function(_) return {
          { value = { shot_num = '1' } },
          { value = { shot_num = '3' } },
        } end,
        get_selection_row = function(_) return 5 end,
      }
      stub_action_state(function(_) return fake_picker end)
      helpers.persistent_state['/save.md'] = nil
      helpers.save_selection_state(0, '/save.md')
      local state = helpers.persistent_state['/save.md']
      assert.is_not_nil(state)
      assert.is_true(state.selections['1'])
      assert.is_true(state.selections['3'])
      assert.are.equal(5, state.cursor_row)
      helpers.persistent_state['/save.md'] = nil
      stub_action_state(function(_) return nil end)
    end)

    it('restore_selection_state no-ops when no saved state', function()
      stub_action_state(function(_) error('should not be called') end)
      assert.has_no.errors(function()
        helpers.restore_selection_state(0, '/no/state.md')
      end)
      stub_action_state(function(_) return nil end)
    end)

    it('restore_selection_state retries when picker not ready', function()
      helpers.persistent_state['/r.md'] = { selections = { ['1'] = true }, cursor_row = 0 }
      stub_action_state(function(_) return nil end)
      local original_defer = vim.defer_fn
      local deferred = false
      vim.defer_fn = function(_, _) deferred = true end
      helpers.restore_selection_state(0, '/r.md', 0)
      assert.is_true(deferred)
      vim.defer_fn = original_defer
      helpers.persistent_state['/r.md'] = nil
    end)

    it('restore_selection_state stops retrying after max attempts', function()
      helpers.persistent_state['/r2.md'] = { selections = { ['1'] = true }, cursor_row = 0 }
      stub_action_state(function(_) return nil end)
      local original_defer = vim.defer_fn
      local defer_count = 0
      vim.defer_fn = function(_, _) defer_count = defer_count + 1 end
      helpers.restore_selection_state(0, '/r2.md', 100)
      assert.are.equal(0, defer_count)
      vim.defer_fn = original_defer
      helpers.persistent_state['/r2.md'] = nil
    end)

    it('restore_selection_state selects rows when picker ready', function()
      helpers.persistent_state['/x.md'] = {
        selections = { ['1'] = true, ['3'] = true },
        cursor_row = 2,
      }
      local selected_rows = {}
      local toggled = 0
      local fake_manager = {}
      fake_manager.iter = function(_)
        local entries = {
          { value = { shot_num = '1' } },
          { value = { shot_num = '2' } },
          { value = { shot_num = '3' } },
        }
        local i = 0
        return function()
          i = i + 1
          return entries[i]
        end
      end
      local fake_picker = {
        _multi = {},
        manager = fake_manager,
        set_selection = function(_, row)
          table.insert(selected_rows, row)
        end,
      }
      stub_action_state(function(_) return fake_picker end)
      stub_actions(function(_) toggled = toggled + 1 end)
      helpers.restore_selection_state(0, '/x.md')
      assert.is_true(toggled >= 2)
      assert.is_true(#selected_rows >= 2)
      helpers.persistent_state['/x.md'] = nil
      stub_action_state(function(_) return nil end)
      stub_actions(function(_) end)
    end)
  end)
end)

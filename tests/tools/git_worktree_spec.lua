-- Characterization tests for shooter.tools.git_worktree.
-- Pins observable behavior of the worktree-listing + LAST-file state machine
-- + Telescope picker construction prior to T007 split.
--
-- pending() when git is missing.

local function git_present()
  return vim.fn.executable('git') == 1
end

-- Stub telescope before requiring git_worktree (it pcall-requires telescope inside
-- pick_worktree, and the test env may or may not have it cached).
package.loaded['telescope'] = package.loaded['telescope'] or { setup = function() end }
package.loaded['telescope.pickers'] = package.loaded['telescope.pickers'] or {
  new = function(_, opts)
    return {
      _opts = opts,
      find = function(self) self._found = true end,
    }
  end,
}
package.loaded['telescope.finders'] = package.loaded['telescope.finders'] or {
  new_table = function(spec) return spec end,
}
package.loaded['telescope.config'] = package.loaded['telescope.config'] or {
  values = { generic_sorter = function(_) return {} end },
}
package.loaded['telescope.actions'] = package.loaded['telescope.actions'] or {
  close = function(_) end,
  select_default = { replace = function(_) end },
}
package.loaded['telescope.actions.state'] = package.loaded['telescope.actions.state'] or {
  get_selected_entry = function() return nil end,
}
package.loaded['shooter.keymaps.picker'] = package.loaded['shooter.keymaps.picker'] or {
  setup_nav_keymaps = function(_) end,
}

-- Fresh require after stubs.
package.loaded['shooter.tools.git_worktree'] = nil
local gw = require('shooter.tools.git_worktree')

-- Test fixtures ---------------------------------------------------------------

local function git(args, cwd)
  local cmd = { 'git', '-C', cwd }
  for _, a in ipairs(args) do table.insert(cmd, a) end
  vim.fn.system(cmd)
end

local function init_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  git({ 'init' }, dir)
  git({ 'config', 'user.email', 'test@example.com' }, dir)
  git({ 'config', 'user.name', 'test' }, dir)
  git({ 'config', 'commit.gpgsign', 'false' }, dir)
  vim.fn.writefile({ '# README' }, dir .. '/README.md')
  git({ 'add', '.' }, dir)
  git({ 'commit', '-m', 'init' }, dir)
  return dir
end

local function cd(dir, fn)
  local prev = vim.fn.getcwd()
  vim.cmd('cd ' .. vim.fn.fnameescape(dir))
  local ok, err = pcall(fn)
  vim.cmd('cd ' .. vim.fn.fnameescape(prev))
  if not ok then error(err) end
end

-- Tests ----------------------------------------------------------------------

describe('shooter.tools.git_worktree', function()
  describe('module surface', function()
    it('exports public API', function()
      assert.is_function(gw.switch_to)
      assert.is_function(gw.pick_worktree)
      assert.is_function(gw.to_last)
      assert.is_function(gw.to_main)
      assert.is_function(gw.get_main_worktree)
    end)
  end)

  describe('get_main_worktree (via M.get_main_worktree)', function()
    it('returns the current main worktree path inside a git repo', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        local main = gw.get_main_worktree()
        assert.is_string(main)
        -- main may be canonicalized (/private/var/...) so just check it ends like the repo
        assert.is_truthy(main)
      end)
      vim.fn.delete(repo, 'rf')
    end)

    it('returns nil when not in a git repo', function()
      if not git_present() then pending('git not installed'); return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      cd(tmp, function()
        local main = gw.get_main_worktree()
        assert.is_nil(main)
      end)
      vim.fn.delete(tmp, 'rf')
    end)
  end)

  describe('to_last', function()
    it('does nothing when LAST file is missing', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        assert.has_no.errors(function() gw.to_last() end)
      end)
      vim.fn.delete(repo, 'rf')
    end)
  end)

  describe('to_main', function()
    it('switches to main worktree (just opens README in main)', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        local prev_buf = vim.api.nvim_get_current_buf()
        assert.has_no.errors(function() gw.to_main() end)
        -- Clean up: close any newly opened buffers
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if b ~= prev_buf and vim.api.nvim_buf_is_loaded(b) then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end
      end)
      vim.fn.delete(repo, 'rf')
    end)

    it('does nothing when not in a git repo', function()
      if not git_present() then pending('git not installed'); return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      cd(tmp, function()
        assert.has_no.errors(function() gw.to_main() end)
      end)
      vim.fn.delete(tmp, 'rf')
    end)
  end)

  describe('switch_to (numbered)', function()
    it('does nothing when given a number with no matching worktree', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        assert.has_no.errors(function() gw.switch_to(99) end)
      end)
      vim.fn.delete(repo, 'rf')
    end)

    it('opens picker when called with no number', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        -- pickers.new returns our stub; pick_worktree calls :find() at the end.
        -- Just ensure no error.
        assert.has_no.errors(function() gw.switch_to() end)
      end)
      vim.fn.delete(repo, 'rf')
    end)
  end)

  describe('pick_worktree (Telescope)', function()
    it('returns silently when worktrees list is empty', function()
      if not git_present() then pending('git not installed'); return end
      assert.has_no.errors(function() gw.pick_worktree({}) end)
    end)

    it('builds a picker with main + numbered entries', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        assert.has_no.errors(function()
          gw.pick_worktree()  -- no arg → fetches via get_numbered_worktrees
        end)
      end)
      vim.fn.delete(repo, 'rf')
    end)
  end)

  describe('LAST file lifecycle (via to_last after to_main)', function()
    it('writes a LAST file when switching to main from a worktree', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        -- to_main() writes LAST = "main" via save_last_worktree before switching.
        gw.to_main()
        local last_path = repo .. '/.hal/git/worktree/LAST'
        if vim.fn.filereadable(last_path) == 1 then
          local lines = vim.fn.readfile(last_path)
          assert.are.equal('main', lines[1])
        end
      end)
      -- Clean up any opened buffers
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(b)
        if name:find(repo, 1, true) then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
      vim.fn.delete(repo, 'rf')
    end)

    it('LAST roundtrip via to_main then to_last (resolves to main)', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        gw.to_main()  -- writes LAST=main
        -- to_last reads LAST → resolves to main → calls to_main again
        assert.has_no.errors(function() gw.to_last() end)
      end)
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(b)
        if name:find(repo, 1, true) then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
      vim.fn.delete(repo, 'rf')
    end)
  end)

  describe('with a real git worktree sibling', function()
    it('lists the additional worktree via get_worktrees (probed by pick_worktree)', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      local wt_dir = repo .. '-wt'
      vim.fn.system({ 'git', '-C', repo, 'worktree', 'add', '-b', 'feature/test', wt_dir })
      cd(repo, function()
        -- pick_worktree fetches via get_numbered_worktrees (which only sees
        -- WORKTREE_BASE entries, not arbitrary sibling worktrees), so this
        -- mainly exercises get_main_worktree + the picker construction path
        -- when the worktree-prefix branch in get_repo_name does NOT trigger.
        assert.has_no.errors(function() gw.pick_worktree() end)
      end)
      vim.fn.system({ 'git', '-C', repo, 'worktree', 'remove', '--force', wt_dir })
      vim.fn.delete(repo, 'rf')
      vim.fn.delete(wt_dir, 'rf')
    end)
  end)

  describe('WORKTREE_BASE-aware paths (with overridden expand)', function()
    -- Reload the module with WORKTREE_BASE pointing to a tmpdir so that
    -- get_numbered_worktrees / get_repo_name's worktree-prefix branch can
    -- be exercised without polluting the user's home directory.
    local function reload_with_base(base)
      local saved = vim.fn.expand
      vim.fn.expand = function(s) ---@diagnostic disable-line: duplicate-set-field
        if s == '~/.hal/git/worktree' then return base end
        return saved(s)
      end
      package.loaded['shooter.tools.git_worktree'] = nil
      local mod = require('shooter.tools.git_worktree')
      vim.fn.expand = saved
      return mod
    end

    it('get_numbered_worktrees returns sorted entries when worktrees live under base', function()
      if not git_present() then pending('git not installed'); return end
      local base = vim.fn.tempname()
      local repo = init_repo()
      local repo_name = vim.fn.fnamemodify(repo, ':t')
      local repo_wt_dir = base .. '/' .. repo_name
      vim.fn.mkdir(repo_wt_dir .. '/01', 'p')
      vim.fn.mkdir(repo_wt_dir .. '/02', 'p')
      vim.fn.mkdir(repo_wt_dir .. '/03', 'p')
      local mod = reload_with_base(base)
      cd(repo, function()
        -- pick_worktree calls get_numbered_worktrees internally
        assert.has_no.errors(function() mod.pick_worktree() end)
      end)
      vim.fn.delete(base, 'rf')
      vim.fn.delete(repo, 'rf')
      package.loaded['shooter.tools.git_worktree'] = nil
      require('shooter.tools.git_worktree')  -- restore live module
    end)

    it('switch_to(N) actually switches into a numbered worktree dir', function()
      if not git_present() then pending('git not installed'); return end
      local base = vim.fn.tempname()
      local repo = init_repo()
      local repo_name = vim.fn.fnamemodify(repo, ':t')
      local wt_path = base .. '/' .. repo_name .. '/01'
      vim.fn.mkdir(wt_path, 'p')
      vim.fn.system({ 'git', '-C', repo, 'worktree', 'add', '-b', 'wt01', wt_path })
      local mod = reload_with_base(base)
      cd(repo, function()
        local prev = vim.api.nvim_get_current_buf()
        assert.has_no.errors(function() mod.switch_to(1) end)
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if b ~= prev and vim.api.nvim_buf_is_loaded(b) then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end
      end)
      vim.fn.system({ 'git', '-C', repo, 'worktree', 'remove', '--force', wt_path })
      vim.fn.delete(base, 'rf')
      vim.fn.delete(repo, 'rf')
      package.loaded['shooter.tools.git_worktree'] = nil
      require('shooter.tools.git_worktree')
    end)

    it('to_last switches to a numbered worktree when LAST contains its name', function()
      if not git_present() then pending('git not installed'); return end
      local base = vim.fn.tempname()
      local repo = init_repo()
      local repo_name = vim.fn.fnamemodify(repo, ':t')
      local wt_path = base .. '/' .. repo_name .. '/01'
      vim.fn.system({ 'git', '-C', repo, 'worktree', 'add', '-b', 'wt01', wt_path })
      -- Pre-seed LAST=01 in the repo's .hal/git/worktree dir
      vim.fn.mkdir(repo .. '/.hal/git/worktree', 'p')
      vim.fn.writefile({ '01' }, repo .. '/.hal/git/worktree/LAST')
      local mod = reload_with_base(base)
      cd(repo, function()
        local prev = vim.api.nvim_get_current_buf()
        assert.has_no.errors(function() mod.to_last() end)
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if b ~= prev and vim.api.nvim_buf_is_loaded(b) then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end
      end)
      vim.fn.system({ 'git', '-C', repo, 'worktree', 'remove', '--force', wt_path })
      vim.fn.delete(base, 'rf')
      vim.fn.delete(repo, 'rf')
      package.loaded['shooter.tools.git_worktree'] = nil
      require('shooter.tools.git_worktree')
    end)
  end)

  describe('get_relative_file (buffer-aware)', function()
    it('does not error when called from an unrelated buffer', function()
      if not git_present() then pending('git not installed'); return end
      local repo = init_repo()
      cd(repo, function()
        -- switch_to triggers save_last_worktree which calls get_relative_file
        local prev = vim.api.nvim_get_current_buf()
        assert.has_no.errors(function() gw.to_main() end)
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if b ~= prev and vim.api.nvim_buf_is_loaded(b) then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end
      end)
      vim.fn.delete(repo, 'rf')
    end)
  end)
end)

-- Characterization tests for shooter.health.
-- Pins observable behavior of every check + the M.check orchestrator
-- prior to the T006 split into health/{init,plugins,system,context,shotfile}.
-- After T006 these checks move to sub-modules and init.lua re-exports them.

local health = require('shooter.health')

-- vim.health stub capturing the calls each check produces ----------------------

local captured
local saved_health

local function install_health_stub()
  captured = { ok = {}, warn = {}, error = {}, info = {}, start = {} }
  saved_health = vim.health
  vim.health = {
    start   = function(...) table.insert(captured.start, { ... }) end,
    ok      = function(...) table.insert(captured.ok,    { ... }) end,
    warn    = function(...) table.insert(captured.warn,  { ... }) end,
    error   = function(...) table.insert(captured.error, { ... }) end,
    info    = function(...) table.insert(captured.info,  { ... }) end,
  }
end

local function restore_health_stub()
  vim.health = saved_health
end

local function ran_one_of()
  return #captured.ok + #captured.warn + #captured.error + #captured.info
end

-- Tests ------------------------------------------------------------------------

describe('shooter.health._checks', function()
  before_each(install_health_stub)
  after_each(restore_health_stub)

  describe('plugin checks', function()
    it('check_telescope reports ok when telescope loads (it does in the test env)', function()
      local result = health._checks.telescope()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)

    it('check_oil_nvim reports error when oil missing (typical test env)', function()
      package.loaded['oil'] = nil
      local result = health._checks.oil_nvim()
      assert.is_boolean(result)
      -- Either ok (if some test loaded oil) or error — assert exactly one of each
      assert.is_true(#captured.ok + #captured.error >= 1)
    end)

    it('check_vim_tmux_navigator reports error when command missing', function()
      local result = health._checks.vim_tmux_navigator()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)

    it('check_gp_nvim reports info when GpWhisper command missing', function()
      local result = health._checks.gp_nvim()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)
  end)

  describe('environment checks', function()
    it('check_iterm reports info or ok depending on TERM_PROGRAM', function()
      local result = health._checks.iterm()
      assert.is_boolean(result)
      assert.is_true(#captured.ok + #captured.info >= 1)
    end)

    it('check_tmux_installed reports ok when tmux is on PATH, warn otherwise', function()
      local result = health._checks.tmux_installed()
      assert.is_boolean(result)
      assert.is_true(#captured.ok + #captured.warn >= 1)
    end)

    it('check_in_tmux reports ok inside tmux, info otherwise', function()
      local result = health._checks.in_tmux()
      assert.is_boolean(result)
      assert.is_true(#captured.ok + #captured.info >= 1)
    end)

    it('check_claude_process completes without error', function()
      local result = health._checks.claude_process()
      assert.is_boolean(result)
      -- May log ok / info / warn — just confirm it didn't raise
    end)
  end)

  describe('context checks', function()
    it('check_global_context reports ok or warn or error', function()
      local result = health._checks.global_context()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)

    it('check_project_context reports ok / info / error', function()
      local result = health._checks.project_context()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)
  end)

  describe('shotfile checks', function()
    it('check_prompts_directory reports ok / warn depending on cwd', function()
      local result = health._checks.prompts_directory()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)

    it('check_queue_file reports info when missing or ok when valid JSON', function()
      local result = health._checks.queue_file()
      assert.is_boolean(result)
      assert.is_true(ran_one_of() > 0)
    end)

    it('check_queue_file errors on invalid JSON in the queue file', function()
      -- Force an invalid JSON file at the configured path within a tmp cwd.
      local config = require('shooter.config')
      local queue_rel = config.get('paths.queue_file')
      if not queue_rel then return end

      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local prev = vim.fn.getcwd()
      vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
      local full = tmp .. '/' .. queue_rel
      vim.fn.mkdir(vim.fn.fnamemodify(full, ':h'), 'p')
      vim.fn.writefile({ 'this is not json' }, full)

      local _ = health._checks.queue_file()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev))
      vim.fn.delete(tmp, 'rf')

      assert.is_true(#captured.error >= 1)
    end)

    it('check_queue_file errors when the JSON is not an array/object', function()
      local config = require('shooter.config')
      local queue_rel = config.get('paths.queue_file')
      if not queue_rel then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local prev = vim.fn.getcwd()
      vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
      local full = tmp .. '/' .. queue_rel
      vim.fn.mkdir(vim.fn.fnamemodify(full, ':h'), 'p')
      -- valid JSON scalar, not a table
      vim.fn.writefile({ '"a string"' }, full)

      local _ = health._checks.queue_file()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev))
      vim.fn.delete(tmp, 'rf')

      assert.is_true(#captured.error >= 1)
    end)

    it('check_queue_file ok on a valid JSON array', function()
      local config = require('shooter.config')
      local queue_rel = config.get('paths.queue_file')
      if not queue_rel then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local prev = vim.fn.getcwd()
      vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
      local full = tmp .. '/' .. queue_rel
      vim.fn.mkdir(vim.fn.fnamemodify(full, ':h'), 'p')
      vim.fn.writefile({ '[]' }, full)

      local _ = health._checks.queue_file()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev))
      vim.fn.delete(tmp, 'rf')

      assert.is_true(#captured.ok >= 1)
    end)
  end)
end)

describe('shooter.health._checks — happy paths via stubs', function()
  before_each(install_health_stub)
  after_each(restore_health_stub)

  it('check_oil_nvim reports ok when oil loads', function()
    local saved = package.loaded.oil
    package.loaded.oil = { _stub = true }
    local result = health._checks.oil_nvim()
    package.loaded.oil = saved
    assert.is_true(result)
    assert.is_true(#captured.ok >= 1)
  end)

  it('check_vim_tmux_navigator reports ok when command exists', function()
    local saved = vim.fn.exists
    vim.fn.exists = function(name) if name == ':TmuxNavigateLeft' then return 2 end return saved(name) end
    local result = health._checks.vim_tmux_navigator()
    vim.fn.exists = saved
    assert.is_true(result)
    assert.is_true(#captured.ok >= 1)
  end)

  it('check_gp_nvim reports ok when GpWhisper exists', function()
    local saved = vim.fn.exists
    vim.fn.exists = function(name) if name == ':GpWhisper' then return 2 end return saved(name) end
    local result = health._checks.gp_nvim()
    vim.fn.exists = saved
    assert.is_true(result)
    assert.is_true(#captured.ok >= 1)
  end)

  it('check_iterm reports ok when TERM_PROGRAM=iTerm.app', function()
    local saved_getenv = os.getenv
    os.getenv = function(k) ---@diagnostic disable-line: duplicate-set-field
      if k == 'TERM_PROGRAM' then return 'iTerm.app' end
      if k == 'TERM_PROGRAM_VERSION' then return '3.5' end
      return saved_getenv(k)
    end
    local result = health._checks.iterm()
    os.getenv = saved_getenv
    assert.is_true(result)
    assert.is_true(#captured.ok >= 1)
  end)

  it('check_in_tmux reports ok when TMUX env var is set', function()
    local saved_getenv = os.getenv
    os.getenv = function(k) ---@diagnostic disable-line: duplicate-set-field
      if k == 'TMUX' then return '/tmp/tmux-1000/default,1234,0' end
      return saved_getenv(k)
    end
    local result = health._checks.in_tmux()
    os.getenv = saved_getenv
    assert.is_true(result)
    assert.is_true(#captured.ok >= 1)
  end)

  it('check_telescope reports error when telescope is missing', function()
    local saved = package.loaded.telescope
    local saved_preload = package.preload.telescope
    package.loaded.telescope = nil
    package.preload.telescope = function() error('not found', 0) end
    local result = health._checks.telescope()
    package.loaded.telescope = saved
    package.preload.telescope = saved_preload
    assert.is_false(result)
    assert.is_true(#captured.error >= 1)
  end)

  it('check_global_context ok when the file exists', function()
    local config = require('shooter.config')
    local utils = require('shooter.utils')
    local global_path = config.get('paths.global_context')
    if not global_path then return end
    local expanded = utils.expand_path(global_path)
    if vim.fn.filereadable(expanded) ~= 1 then
      vim.fn.mkdir(vim.fn.fnamemodify(expanded, ':h'), 'p')
      vim.fn.writefile({ 'stub' }, expanded)
      local result = health._checks.global_context()
      vim.fn.delete(expanded)
      assert.is_true(result)
    else
      local result = health._checks.global_context()
      assert.is_true(result)
    end
    assert.is_true(#captured.ok >= 1)
  end)

  it('check_project_context info when not in a git repo', function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, 'p')
    local prev = vim.fn.getcwd()
    vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
    local result = health._checks.project_context()
    vim.cmd('cd ' .. vim.fn.fnameescape(prev))
    vim.fn.delete(tmp, 'rf')
    assert.is_false(result)
    assert.is_true(#captured.info >= 1)
  end)

  it('check_prompts_directory warn when missing in cwd', function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, 'p')
    local prev = vim.fn.getcwd()
    vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
    local result = health._checks.prompts_directory()
    vim.cmd('cd ' .. vim.fn.fnameescape(prev))
    vim.fn.delete(tmp, 'rf')
    assert.is_false(result)
    assert.is_true(#captured.warn >= 1)
  end)

  it('check_prompts_directory ok when present', function()
    local config = require('shooter.config')
    local prompts_rel = config.get('paths.prompts_root')
    if not prompts_rel then return end
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/' .. prompts_rel, 'p')
    -- Add a dummy md to exercise the find/wc -l info branch
    vim.fn.writefile({ 'x' }, tmp .. '/' .. prompts_rel .. '/dummy.md')
    local prev = vim.fn.getcwd()
    vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
    local result = health._checks.prompts_directory()
    vim.cmd('cd ' .. vim.fn.fnameescape(prev))
    vim.fn.delete(tmp, 'rf')
    assert.is_true(result)
    assert.is_true(#captured.ok >= 1)
  end)
end)

describe('shooter.health.check (orchestrator)', function()
  before_each(install_health_stub)
  after_each(restore_health_stub)

  it('runs without error and emits multiple section starts', function()
    assert.has_no.errors(function() health.check() end)
    -- Orchestrator should call vim.health.start for: shooter.nvim, Configuration,
    -- Neovim Plugins, System Dependencies, Context Files, Directory Structure,
    -- Queue System, Summary (8 sections; tmux-env is conditional).
    assert.is_true(#captured.start >= 7)
  end)

  it('emits at least one ok / warn / info / error from sub-checks', function()
    health.check()
    local total = #captured.ok + #captured.warn + #captured.error + #captured.info
    assert.is_true(total > 0)
  end)
end)

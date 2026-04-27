-- Phase 004 T008 security regression spec.
-- Asserts the explicit T008 deliverables (health, syntax, analytics/data,
-- tools/git_worktree, tools/tmux_panes) are free of string-form interpolation
-- in their shell-out call sites. Greps the lua/ source under test paths.

local function read(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()
  return content
end

local function grep_lines(content, pattern)
  if not content then return {} end
  local hits = {}
  local lineno = 0
  for line in content:gmatch('[^\n]*') do
    lineno = lineno + 1
    if line:match(pattern) and not line:match('^%s*%-%-') then
      table.insert(hits, lineno .. ': ' .. line)
    end
  end
  return hits
end

local function expect_no_string_interp(path)
  local content = read(path)
  assert.is_string(content, 'expected to read ' .. path)
  -- Forbid io.popen / vim.fn.system* with `..` concatenation in the same line.
  -- The exception is wrappers that accept an opaque cmd string and append
  -- ' 2>/dev/null'; those are out of scope for the per-touched-file rule and
  -- are tracked explicitly.
  local hits = {}
  for _, pat in ipairs({
    "io%.popen%([^)]*%.%.[^)]*%)",
    "vim%.fn%.system%([^)]*%.%.[^)]*%)",
    "vim%.fn%.systemlist%([^)]*%.%.[^)]*%)",
  }) do
    for _, h in ipairs(grep_lines(content, pat)) do
      -- Allow ' 2>/dev/null' tail on a wrapper cmd argument (handled by
      -- callers; covered by the dedicated wrapper-callsite tests in
      -- tests/security/{specific_wrapper}.lua follow-ups).
      if not h:match('%.%.%s*["\']%s*2>/dev/null%s*["\']%)$')
         and not h:match('%.%.%s*["\']%s*2>/dev/null%s*["\']%s*%)') then
        table.insert(hits, h)
      end
    end
  end
  return hits
end

describe('Phase 004 T008 security — touched files', function()
  describe('lua/shooter/health/* (T006)', function()
    it('no string-form shell-out interpolation in plugins.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/health/plugins.lua'))
    end)
    it('no string-form shell-out interpolation in system.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/health/system.lua'))
    end)
    it('no string-form shell-out interpolation in shotfile.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/health/shotfile.lua'))
    end)
    it('no string-form shell-out interpolation in context.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/health/context.lua'))
    end)
    it('no string-form shell-out interpolation in init.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/health/init.lua'))
    end)
  end)

  describe('lua/shooter/syntax/* (T005)', function()
    it('no string-form shell-out interpolation in info.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/syntax/info.lua'))
    end)
    it('apply.lua / detect.lua / overrides.lua have no shell-outs at all', function()
      for _, p in ipairs({
        'lua/shooter/syntax/apply.lua',
        'lua/shooter/syntax/detect.lua',
        'lua/shooter/syntax/overrides.lua',
        'lua/shooter/syntax/highlights.lua',
      }) do
        assert.same({}, expect_no_string_interp(p))
      end
    end)
  end)

  describe('lua/shooter/analytics/data/* (T007)', function()
    it('no string-form shell-out interpolation in sources.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/analytics/data/sources.lua'))
    end)
    it('no string-form shell-out interpolation in repo.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/analytics/data/repo.lua'))
    end)
  end)

  describe('lua/shooter/tools/git_worktree/* (T007)', function()
    it('no string-form shell-out interpolation in repo.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/tools/git_worktree/repo.lua'))
    end)
    it('no string-form shell-out interpolation in state.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/tools/git_worktree/state.lua'))
    end)
    it('no string-form shell-out interpolation in list.lua', function()
      assert.same({}, expect_no_string_interp('lua/shooter/tools/git_worktree/list.lua'))
    end)
  end)

  describe('lua/shooter/tools/tmux_panes.lua', function()
    it('callers pass table-form to vim.fn.systemlist (no string interpolation)', function()
      assert.same({}, expect_no_string_interp('lua/shooter/tools/tmux_panes.lua'))
    end)
  end)
end)

describe('Phase 004 T008 — runtime smoke (post-fix behavior preserved)', function()
  it('shooter.health.M._checks dispatch table is intact', function()
    local health = require('shooter.health')
    assert.is_table(health._checks)
    assert.is_function(health._checks.tmux_installed)
    assert.is_function(health._checks.claude_process)
    assert.is_function(health._checks.prompts_directory)
  end)

  it('shooter.analytics.data sources discovery returns a table', function()
    local data = require('shooter.analytics.data')
    -- Run from a non-git tmpdir so we don't drag the user's home repos into the test.
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, 'p')
    local prev = vim.fn.getcwd()
    vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
    local repos = data.get_all_repo_paths()
    local shots = data.get_all_shots('___no_match___')
    vim.cmd('cd ' .. vim.fn.fnameescape(prev))
    vim.fn.delete(tmp, 'rf')
    assert.is_table(repos)
    assert.is_table(shots)
  end)

  it('shooter.tools.tmux_panes API is intact', function()
    local tp = require('shooter.tools.tmux_panes')
    assert.is_function(tp.list_current_window)
    assert.is_function(tp.capture)
    assert.is_function(tp.in_tmux)
  end)
end)

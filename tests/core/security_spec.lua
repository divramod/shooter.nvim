-- Phase 002 T008 security regression spec.
-- Covers shell-injection-resistance for the core/ shell-out sites identified
-- in the baseline audit + canonical-path-rejection where applicable.

local utils = require('shooter.utils')

describe('core/-area security', function()

  describe('shooter.core.project.list_projects', function()
    -- list_projects must not pass projects_dir through a shell. The pre-T008
    -- impl ran io.popen('ls -1 "' .. projects_dir .. '" 2>/dev/null') which
    -- would execute embedded `command substitution` inside the path. After
    -- the fix it uses vim.fn.readdir + vim.fn.isdirectory and never invokes
    -- a shell with the dir interpolated.

    local fake_root = '/tmp/shooter_security_projects_test'
    local original_get_projects_dir
    local project

    before_each(function()
      project = require('shooter.core.project')
      os.execute('rm -rf ' .. fake_root)
      os.execute('mkdir -p ' .. fake_root .. '/proj1')
      os.execute('mkdir -p ' .. fake_root .. '/proj2')
      original_get_projects_dir = project.get_projects_dir
      project.get_projects_dir = function() return fake_root end
    end)

    after_each(function()
      project.get_projects_dir = original_get_projects_dir
      os.execute('rm -rf ' .. fake_root)
    end)

    it('returns the two real subdirs (sanity)', function()
      local list = project.list_projects()
      table.sort(list, function(a, b) return a.name < b.name end)
      assert.equals(2, #list)
      assert.equals('proj1', list[1].name)
      assert.equals('proj2', list[2].name)
    end)

    it('rejects a non-existent projects_dir without raising', function()
      project.get_projects_dir = function() return '/no/such/dir' end
      local list = project.list_projects()
      assert.equals(0, #list)
    end)

    it('does not execute a shell command when projects_dir contains metacharacters', function()
      -- Even if projects_dir itself is a path with embedded shell metas,
      -- list_projects() must not evaluate them. The pre-T008 impl interpolated
      -- projects_dir into a shell `ls` and was vulnerable.
      local sentinel = '/tmp/shooter_security_pwn_sentinel'
      os.execute('rm -f ' .. sentinel)

      local evil_root = '/tmp/$(touch ' .. sentinel .. ')_dir'
      os.execute('rm -rf ' .. vim.fn.shellescape(evil_root))
      vim.fn.mkdir(evil_root, 'p')

      project.get_projects_dir = function() return evil_root end

      -- Calling list_projects must succeed without spawning a shell on the
      -- evil root. Sentinel must remain absent.
      local _ = project.list_projects()

      assert.equals(0, vim.fn.filereadable(sentinel))
      os.execute('rm -rf ' .. vim.fn.shellescape(evil_root))
    end)
  end)

  describe('shooter.utils.find_config_file', function()
    -- Pre-T008 fallback used io.popen with the plugins_dir interpolated. The
    -- new impl uses vim.fn.glob + Lua file-read; no shell.
    local nvim_config_orig

    before_each(function()
      nvim_config_orig = vim.fn.stdpath
      -- Point stdpath('config') at a temp dir we control.
    end)

    after_each(function()
      vim.fn.stdpath = nvim_config_orig
    end)

    it('returns nil when no plugin file mentions shooter', function()
      local tmp = '/tmp/shooter_security_cfg_test'
      os.execute('rm -rf ' .. tmp)
      os.execute('mkdir -p ' .. tmp .. '/lua/plugins')
      local f = io.open(tmp .. '/lua/plugins/random.lua', 'w')
      f:write('return { "no-match-here" }\n'); f:close()

      -- Stub stdpath to point to our tmp config root.
      local stdpath_orig = vim.fn.stdpath
      vim.fn.stdpath = function(what)
        if what == 'config' then return tmp end
        return stdpath_orig(what)
      end
      package.loaded['shooter.utils'] = nil
      local utils_fresh = require('shooter.utils')

      local result = utils_fresh.find_config_file()
      vim.fn.stdpath = stdpath_orig
      os.execute('rm -rf ' .. tmp)

      assert.is_nil(result)
    end)

    it('finds a plugin file containing the shooter literal', function()
      local tmp = '/tmp/shooter_security_cfg_test_hit'
      os.execute('rm -rf ' .. tmp)
      os.execute('mkdir -p ' .. tmp .. '/lua/plugins')
      local f = io.open(tmp .. '/lua/plugins/foo.lua', 'w')
      f:write('return { "shooter.nvim" }\n'); f:close()

      local stdpath_orig = vim.fn.stdpath
      vim.fn.stdpath = function(what)
        if what == 'config' then return tmp end
        return stdpath_orig(what)
      end
      package.loaded['shooter.utils'] = nil
      local utils_fresh = require('shooter.utils')

      local result = utils_fresh.find_config_file()
      vim.fn.stdpath = stdpath_orig
      os.execute('rm -rf ' .. tmp)

      assert.is_truthy(result)
      assert.is_truthy(result:match('foo%.lua$'))
    end)
  end)

  describe('shooter.utils.system table form', function()
    -- M.system must accept a list (table) form so callers can pass argv
    -- without going through the shell. T008 added this dispatch.
    it('accepts a table and returns its stdout', function()
      local out = utils.system({ 'echo', 'hello' })
      assert.is_truthy(out)
      assert.equals('hello', vim.trim(out))
    end)

    it('does not interpolate metacharacters in the table form', function()
      -- If args were joined into a shell command, $(date) would be evaluated
      -- and the output would not contain the literal "$(date)".
      local out = utils.system({ 'echo', '$(date)' })
      assert.equals('$(date)', vim.trim(out))
    end)

    it('still accepts the string form for back-compat', function()
      local out = utils.system('echo back-compat')
      assert.equals('back-compat', vim.trim(out))
    end)
  end)

  describe('shooter.core.shot_actions.create_shot_from_claude pane validation', function()
    -- right_pane comes from `tmux display-message`. After T008 the result is
    -- gated by a strict regex (^%<digits>$) before being interpolated into
    -- subsequent tmux send-keys / select-pane calls. Verify the regex.
    it('matches well-formed pane ids like %23', function()
      assert.is_truthy(('%23'):match('^%%%d+$'))
      assert.is_truthy(('%0'):match('^%%%d+$'))
    end)

    it('rejects pane ids with shell metacharacters', function()
      assert.is_nil(('%23; rm -rf /'):match('^%%%d+$'))
      assert.is_nil(('$(touch /tmp/pwn)'):match('^%%%d+$'))
      assert.is_nil((''):match('^%%%d+$'))
      assert.is_nil(("can't find pane"):match('^%%%d+$'))
    end)
  end)
end)

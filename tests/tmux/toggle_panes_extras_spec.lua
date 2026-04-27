-- Extended characterization tests for shooter.tmux.toggle_panes.
-- The existing toggle_panes_spec.lua covers module surface + state queries;
-- these tests exercise the show/hide/toggle pipeline by stubbing io.popen
-- and the tmux.detect / tmux.config_panes / tmux.hidden_session deps.
-- Pins behavior prior to T007 split into toggle_panes/{init,exec,layout,marker,actions,keybinding}.

local function stub_module(name, replacement)
  local saved = package.loaded[name]
  package.loaded[name] = replacement
  return function() package.loaded[name] = saved end
end

-- Stub deps BEFORE loading toggle_panes ---------------------------------------

local restore_detect = stub_module('shooter.tmux.detect', {
  check_tmux_installed = function() return true end,
  in_tmux = function() return true end,
})

local restore_config = stub_module('shooter.tmux.config_panes', {
  find_by_name = function(name)
    if name == 'unknown' then return nil end
    return { name = name, height = 30, focus = false, commands = { 'echo hi' } }
  end,
})

local stub_hidden = {
  get_session_name = function() return '_shooter_hidden' end,
  get_folder_name = function() return 'testfolder' end,
  get_window_name = function(folder, name) return folder .. '-' .. name end,
  hide_pane = function(_pane_id, _window_name) return true end,
  restore_pane = function(_window_name, _height) return '%99' end,
  cleanup_session = function() end,
  find_window = function(_) return nil end,
}
local restore_hidden = stub_module('shooter.tmux.hidden_session', stub_hidden)

local restore_utils = stub_module('shooter.utils', package.loaded['shooter.utils'])

package.loaded['shooter.tmux.toggle_panes'] = nil
local toggle_panes = require('shooter.tmux.toggle_panes')

-- io.popen / os.execute stubs --------------------------------------------------

local saved_popen = io.popen
local saved_execute = os.execute
local popen_handlers = {}
local exec_calls = {}

local function install_stubs()
  exec_calls = {}
  io.popen = function(cmd) ---@diagnostic disable-line: duplicate-set-field
    for pat, response in pairs(popen_handlers) do
      if cmd:match(pat) then
        local lines_iter
        return {
          read = function(_, mode)
            if mode == '*l' then
              if not lines_iter then
                local lines = vim.split(response or '', '\n')
                local i = 0
                lines_iter = function() i = i + 1; return lines[i] end
              end
              return lines_iter()
            end
            return response
          end,
          lines = function()
            local i = 0
            local lines = vim.split(response or '', '\n')
            return function() i = i + 1; return lines[i] end
          end,
          close = function() return true end,
        }
      end
    end
    return nil
  end
  os.execute = function(cmd) ---@diagnostic disable-line: duplicate-set-field
    table.insert(exec_calls, cmd)
    return true
  end
end

local function restore_stubs()
  io.popen = saved_popen
  os.execute = saved_execute
  popen_handlers = {}
end

-- Tests ----------------------------------------------------------------------

describe('shooter.tmux.toggle_panes — extras', function()
  before_each(function()
    toggle_panes.clear_state()
    install_stubs()
  end)
  after_each(function()
    restore_stubs()
    toggle_panes.clear_state()
  end)

  describe('show', function()
    it('returns false for an unknown pane name', function()
      local ok = toggle_panes.show('unknown')
      assert.is_false(ok)
    end)

    it('creates a new pane when none exists for the name', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',  -- pane_exists checks `result == 'yes'`
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      local ok = toggle_panes.show('alpha')
      assert.is_true(ok)
      local state = toggle_panes.get_state('alpha')
      assert.is_table(state)
      assert.are.equal('%42', state.pane_id)
    end)

    it('returns true when pane already visible (idempotent)', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      assert.is_true(toggle_panes.show('alpha'))
      -- Second call: pane_id set + pane_exists(true) → returns true without re-creating
      assert.is_true(toggle_panes.show('alpha'))
    end)

    it('returns false when create_bottom_pane fails (empty pane_id)', function()
      popen_handlers = {
        ['split%-window'] = '',  -- empty → create returns nil
      }
      local ok = toggle_panes.show('alpha')
      assert.is_false(ok)
    end)

    it('restores from hidden session when the pane was hidden', function()
      popen_handlers = { ['list%-panes'] = '' }  -- pane_exists false
      -- Pre-seed state: pane was hidden via M.hide previously (window_name set)
      toggle_panes.show('beta')  -- create initial
      -- Now mark it as hidden
      local state = toggle_panes.get_state('beta')
      if state then
        state.window_name = 'testfolder-beta'
        state.pane_id = nil
      end
      local ok = toggle_panes.show('beta')
      assert.is_true(ok)
      local s2 = toggle_panes.get_state('beta')
      assert.are.equal('%99', s2.pane_id)  -- stub_hidden.restore_pane returned '%99'
    end)
  end)

  describe('hide', function()
    it('returns false when pane not in state', function()
      assert.is_false(toggle_panes.hide('never_shown'))
    end)

    it('hides a visible pane and returns true', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      toggle_panes.show('gamma')
      local ok = toggle_panes.hide('gamma')
      assert.is_true(ok)
      local state = toggle_panes.get_state('gamma')
      assert.is_nil(state.pane_id)
      assert.are.equal('testfolder-gamma', state.window_name)
    end)

    it('returns false when the tracked pane no longer exists', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      toggle_panes.show('delta')
      -- Now make pane_exists return something other than 'yes'
      popen_handlers['list%-panes'] = 'no'
      local ok = toggle_panes.hide('delta')
      assert.is_false(ok)
    end)
  end)

  describe('toggle', function()
    it('shows when not visible', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      assert.is_true(toggle_panes.toggle('eps'))
      assert.is_true(toggle_panes.is_visible('eps'))
    end)

    it('hides when visible', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      toggle_panes.show('zeta')
      assert.is_true(toggle_panes.toggle('zeta'))
      assert.is_false(toggle_panes.is_visible('zeta'))
    end)
  end)

  describe('is_visible / is_hidden / get_visible_panes', function()
    it('reports visible after a successful show', function()
      popen_handlers = {
        ['split%-window'] = '%42',
        ['list%-panes'] = 'yes',
        ['pane_height'] = '20',
        ['window_height'] = '60',
      }
      toggle_panes.show('eta')
      assert.is_true(toggle_panes.is_visible('eta'))
      local visible = toggle_panes.get_visible_panes()
      assert.is_true(vim.tbl_contains(visible, 'eta'))
    end)

    it('reports hidden via hidden_session.find_window when window matches', function()
      stub_hidden.find_window = function(_) return 'fake-window-id' end
      assert.is_true(toggle_panes.is_hidden('theta'))
      stub_hidden.find_window = function(_) return nil end
    end)
  end)

  describe('setup_tmux_keybinding', function()
    it('runs without error when tmux is detected', function()
      assert.has_no.errors(function() toggle_panes.setup_tmux_keybinding() end)
      -- tmux_run was called via os.execute → exec_calls populated
      assert.is_true(#exec_calls >= 1)
    end)

    it('returns silently when tmux is not detected', function()
      package.loaded['shooter.tmux.detect'] = {
        check_tmux_installed = function() return false end,
        in_tmux = function() return false end,
      }
      package.loaded['shooter.tmux.toggle_panes'] = nil
      local fresh = require('shooter.tmux.toggle_panes')
      assert.has_no.errors(function() fresh.setup_tmux_keybinding() end)
      -- Restore detect stub
      package.loaded['shooter.tmux.detect'] = {
        check_tmux_installed = function() return true end,
        in_tmux = function() return true end,
      }
      package.loaded['shooter.tmux.toggle_panes'] = toggle_panes
    end)
  end)
end)

-- Cleanup module stubs at file end (other tests may load these mods)
restore_detect()
restore_config()
restore_hidden()
restore_utils()

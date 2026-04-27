-- Show / hide / toggle actions + state queries.
-- The module-local state table is owned by init.lua and passed in via
-- new(state). Pulled out of shooter/tmux/toggle_panes.lua during plan 0001
-- phase 004 T007.

local exec = require('shooter.tmux.toggle_panes.exec')
local layout = require('shooter.tmux.toggle_panes.layout')
local marker = require('shooter.tmux.toggle_panes.marker')
local config_panes = require('shooter.tmux.config_panes')
local detect = require('shooter.tmux.detect')
local hidden_session = require('shooter.tmux.hidden_session')

local M = {}

---@param state table
---@return table
function M.new(state)
  local A = {}

  ---@param pane_id string
  ---@param commands string[]
  local function run_commands(pane_id, commands)
    for _, cmd in ipairs(commands) do
      local escaped = cmd:gsub("'", "'\\''")
      exec.tmux_run(string.format("tmux send-keys -t %s '%s' Enter", pane_id, escaped))
      vim.wait(100, function() return false end, 50)
    end
  end

  ---@param name string
  ---@return boolean
  function A.hide(name)
    local pane_state = state[name]
    if not pane_state or not pane_state.pane_id then
      return false
    end

    if not layout.pane_exists(pane_state.pane_id) then
      state[name] = nil
      return false
    end

    pane_state.last_height = layout.get_pane_height_percent(pane_state.pane_id)

    local folder = pane_state.folder or hidden_session.get_folder_name()
    pane_state.folder = folder

    local window_name = layout.get_hidden_window_name(folder, name)

    if hidden_session.hide_pane(pane_state.pane_id, window_name) then
      pane_state.window_name = window_name
      pane_state.pane_id = nil
      return true
    end
    return false
  end

  ---@param name string
  ---@return boolean
  function A.show(name)
    if not detect.check_tmux_installed() or not detect.in_tmux() then
      return false
    end

    local config = config_panes.find_by_name(name)
    if not config then
      return false
    end

    local pane_state = state[name] or {}
    state[name] = pane_state

    if pane_state.pane_id and layout.pane_exists(pane_state.pane_id) then
      return true
    end

    if pane_state.pane_id and not layout.pane_exists(pane_state.pane_id) then
      pane_state.pane_id = nil
    end

    if pane_state.window_name then
      local height = pane_state.last_height or config.height or 30
      local pane_id = hidden_session.restore_pane(pane_state.window_name, height)
      if pane_id then
        pane_state.pane_id = pane_id
        pane_state.window_name = nil
        hidden_session.cleanup_session()
        return true
      end
    end

    local folder = pane_state.folder or hidden_session.get_folder_name()
    local window_name = layout.get_hidden_window_name(folder, name)
    if hidden_session.find_window(window_name) then
      local height = pane_state.last_height or config.height or 30
      local pane_id = hidden_session.restore_pane(window_name, height)
      if pane_id then
        pane_state.pane_id = pane_id
        pane_state.window_name = nil
        pane_state.folder = folder
        hidden_session.cleanup_session()
        return true
      end
    end

    local height = config.height or 30
    local focus = config.focus or false
    local pane_id = layout.create_bottom_pane(height, focus)
    if not pane_id then return false end

    pane_state.pane_id = pane_id
    pane_state.last_height = height
    pane_state.folder = folder

    marker.setup_pane_for_hiding(pane_id, name)

    if not pane_state.commands_run and config.commands and #config.commands > 0 then
      run_commands(pane_id, config.commands)
      pane_state.commands_run = true
    end

    return true
  end

  ---@param name string
  ---@return boolean
  function A.toggle(name)
    local pane_state = state[name]
    if pane_state and pane_state.pane_id and layout.pane_exists(pane_state.pane_id) then
      return A.hide(name)
    end
    return A.show(name)
  end

  ---@param name string
  ---@return boolean
  function A.is_visible(name)
    local pane_state = state[name]
    return pane_state ~= nil
      and pane_state.pane_id ~= nil
      and layout.pane_exists(pane_state.pane_id)
  end

  ---@param name string
  ---@return boolean
  function A.is_hidden(name)
    local pane_state = state[name]
    if pane_state and pane_state.window_name then
      return hidden_session.find_window(pane_state.window_name) ~= nil
    end
    local folder = (pane_state and pane_state.folder) or hidden_session.get_folder_name()
    local window_name = layout.get_hidden_window_name(folder, name)
    return hidden_session.find_window(window_name) ~= nil
  end

  ---@return string[]
  function A.get_visible_panes()
    local visible = {}
    for name, pane_state in pairs(state) do
      if pane_state.pane_id and layout.pane_exists(pane_state.pane_id) then
        table.insert(visible, name)
      end
    end
    return visible
  end

  return A
end

return M

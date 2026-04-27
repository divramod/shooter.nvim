-- Tmux pane layout helpers — heights, existence, creation, window naming.
-- Pulled out of shooter/tmux/toggle_panes.lua during plan 0001 phase 004 T007.

local exec = require('shooter.tmux.toggle_panes.exec')
local hidden_session = require('shooter.tmux.hidden_session')

local M = {}

---@param pane_id string
---@return number
function M.get_pane_height_percent(pane_id)
  local height = exec.tmux_exec(string.format(
    "tmux display -p -t %s '#{pane_height}'",
    pane_id
  ))
  local window_height = exec.tmux_exec("tmux display -p '#{window_height}'")

  if height and window_height then
    local h = tonumber(height) or 0
    local wh = tonumber(window_height) or 1
    return math.floor((h / wh) * 100)
  end
  return 30
end

---@param pane_id string
---@return boolean
function M.pane_exists(pane_id)
  local result = exec.tmux_exec(string.format(
    "tmux list-panes -s -F '#{pane_id}' 2>/dev/null | grep -q '%s' && echo yes",
    pane_id
  ))
  return result == 'yes'
end

---@param height number Height percentage (1-100)
---@param focus boolean Whether to focus the new pane (default: true)
---@return string|nil pane_id
function M.create_bottom_pane(height, focus)
  local flags = focus and '' or '-d '
  local pane_id = exec.tmux_exec(string.format(
    "tmux split-window %s-v -l %d%% -P -F '#{pane_id}'",
    flags,
    height
  ))
  return pane_id and pane_id ~= '' and pane_id or nil
end

---@param folder string
---@param name string
---@return string
function M.get_hidden_window_name(folder, name)
  return hidden_session.get_window_name(folder, name)
end

return M

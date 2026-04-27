-- Temp-file marker tracking so tmux keybindings can find pane name + folder.
-- Files written to /tmp/shooter-{pane,folder}-<sanitized_pane_id>.
-- Pulled out of shooter/tmux/toggle_panes.lua during plan 0001 phase 004 T007.

local hidden_session = require('shooter.tmux.hidden_session')

local M = {}

---@param pane_id string
---@return string
function M.get_pane_name_file(pane_id)
  local clean_id = pane_id:gsub('%%', '')
  return '/tmp/shooter-pane-' .. clean_id
end

---@param pane_id string
---@return string
function M.get_folder_file(pane_id)
  local clean_id = pane_id:gsub('%%', '')
  return '/tmp/shooter-folder-' .. clean_id
end

---@param pane_id string
---@param name string
function M.setup_pane_for_hiding(pane_id, name)
  local filepath = M.get_pane_name_file(pane_id)
  local file = io.open(filepath, 'w')
  if file then
    file:write(name)
    file:close()
  end

  local folder = hidden_session.get_folder_name()
  local folder_path = M.get_folder_file(pane_id)
  local folder_file = io.open(folder_path, 'w')
  if folder_file then
    folder_file:write(folder)
    folder_file:close()
  end
end

return M

-- Re-export surface for shooter.tmux.toggle_panes (split during plan 0001
-- phase 004 T007 from the monolithic shooter/tmux/toggle_panes.lua).
--
-- State table: { [name] = { pane_id, window_name, last_height, commands_run, folder } }

local actions_factory = require('shooter.tmux.toggle_panes.actions')
local keybinding = require('shooter.tmux.toggle_panes.keybinding')

local M = {}

local state = {}
local A = actions_factory.new(state)

-- Action surface
M.hide = A.hide
M.show = A.show
M.toggle = A.toggle
M.is_visible = A.is_visible
M.is_hidden = A.is_hidden
M.get_visible_panes = A.get_visible_panes

---@param name string
---@return table|nil
function M.get_state(name)
  return state[name]
end

function M.clear_state()
  for k in pairs(state) do state[k] = nil end
end

M.setup_tmux_keybinding = keybinding.setup_tmux_keybinding

return M

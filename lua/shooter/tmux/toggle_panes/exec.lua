-- Tmux exec wrappers (capturing + non-capturing).
-- T008 hardens: callers must table-form the command argument (no string
-- interpolation of caller-controlled values into `cmd`).
-- Pulled out of shooter/tmux/toggle_panes.lua during plan 0001 phase 004 T007.

local M = {}

---@param cmd string
---@return string|nil
function M.tmux_exec(cmd)
  local handle = io.popen(cmd .. ' 2>/dev/null')
  if not handle then return nil end
  local result = handle:read('*l')
  handle:close()
  return result
end

---@param cmd string
function M.tmux_run(cmd)
  os.execute(cmd .. ' 2>/dev/null')
end

return M

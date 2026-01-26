-- Tmux pane detection for shooter.nvim
-- Find and validate tmux panes running AI (Claude, opencode, etc.)

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Check if tmux is installed
function M.check_tmux_installed()
  local result = vim.fn.executable('tmux')
  return result == 1
end

-- Check if running in tmux
function M.in_tmux()
  return utils.in_tmux()
end

-- Check if any AI is running (basic check via ps)
function M.check_ai_running()
  if not M.check_tmux_installed() then
    return false
  end
  local providers = require('shooter.providers')
  return providers.check_any_ai_running()
end

-- Alias for backward compatibility
function M.check_claude_running()
  return M.check_ai_running()
end

-- List all tmux panes with their IDs and TTYs
function M.list_all_panes()
  if not M.check_tmux_installed() then
    return {}
  end

  local handle = io.popen("tmux list-panes -F '#{pane_id}:#{pane_tty}' 2>/dev/null")
  if not handle then
    return {}
  end

  local output = handle:read("*a")
  handle:close()

  local panes = {}
  for line in output:gmatch("[^\n]+") do
    local pane_id, pane_tty = line:match("([^:]+):(.+)")
    if pane_id and pane_tty then
      table.insert(panes, {
        id = pane_id,
        tty = pane_tty
      })
    end
  end

  return panes
end

-- Get list of TTYs running any AI
function M.get_ai_ttys()
  local providers = require('shooter.providers')
  return providers.get_ai_ttys()
end

-- Alias for backward compatibility
function M.get_claude_ttys()
  return M.get_ai_ttys()
end

-- Find all panes running any AI
function M.find_all_ai_panes()
  local all_panes = M.list_all_panes()
  local ai_ttys = M.get_ai_ttys()
  local ai_panes = {}

  for _, pane in ipairs(all_panes) do
    local tty_num = pane.tty:match("ttys(%d+)")
    if tty_num and ai_ttys[tty_num] then
      table.insert(ai_panes, pane.id)
    end
  end

  return ai_panes
end

-- Alias for backward compatibility
function M.find_all_claude_panes()
  return M.find_all_ai_panes()
end

-- Find the Nth AI pane (1-indexed, defaults to 1)
-- Returns pane_id or nil if not found
function M.find_ai_pane(pane_index)
  pane_index = pane_index or 1

  local max_panes = config.get('tmux.max_panes')
  if pane_index < 1 or pane_index > max_panes then
    return nil, string.format("Pane index must be between 1 and %d", max_panes)
  end

  if not M.check_tmux_installed() then
    return nil, "tmux is not installed"
  end

  if not M.in_tmux() then
    return nil, "Not running in tmux"
  end

  local ai_panes = M.find_all_ai_panes()

  if pane_index <= #ai_panes then
    return ai_panes[pane_index], nil
  end

  if #ai_panes == 0 then
    return nil, "No tmux pane with AI (Claude/opencode) found in current window"
  else
    return nil, string.format("No AI pane #%d found (only %d pane(s) available)", pane_index, #ai_panes)
  end
end

-- Alias for backward compatibility
function M.find_claude_pane(pane_index)
  return M.find_ai_pane(pane_index)
end

-- Validate pane exists and is accessible
function M.validate_pane(pane_id)
  if not pane_id then
    return false, "No pane ID provided"
  end

  -- Check if pane exists
  local handle = io.popen(string.format("tmux list-panes -F '#{pane_id}' 2>/dev/null | grep -x '%s'", pane_id))
  if not handle then
    return false, "Failed to validate pane"
  end

  local result = handle:read("*a")
  handle:close()

  if not result or result == "" then
    return false, string.format("Pane %s does not exist", pane_id)
  end

  return true, nil
end

-- Get pane count
function M.get_pane_count()
  local panes = M.list_all_panes()
  return #panes
end

-- Get Claude pane count
function M.get_claude_pane_count()
  local claude_panes = M.find_all_claude_panes()
  return #claude_panes
end

return M

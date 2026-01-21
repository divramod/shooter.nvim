-- Tmux pane detection for shooter.nvim
-- Find and validate tmux panes running Claude

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

-- Check if Claude is running (basic check via ps)
function M.check_claude_running()
  if not M.check_tmux_installed() then
    return false
  end

  local handle = io.popen("ps aux | grep '[c]laude' 2>/dev/null")
  if not handle then
    return false
  end

  local result = handle:read("*a")
  handle:close()

  return result and result ~= ""
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

-- Get list of TTYs running Claude
function M.get_claude_ttys()
  local handle = io.popen("ps aux | grep '[c]laude' | awk '{print $7}' 2>/dev/null")
  if not handle then
    return {}
  end

  local output = handle:read("*a")
  handle:close()

  local ttys = {}
  for tty in output:gmatch("[^\n]+") do
    -- Extract tty number (e.g., ttys004 -> 004)
    local tty_num = tty:match("ttys(%d+)")
    if tty_num then
      ttys[tty_num] = true
    end
  end

  return ttys
end

-- Find all panes running Claude
function M.find_all_claude_panes()
  local all_panes = M.list_all_panes()
  local claude_ttys = M.get_claude_ttys()
  local claude_panes = {}

  for _, pane in ipairs(all_panes) do
    -- Extract tty number from pane tty
    local tty_num = pane.tty:match("ttys(%d+)")
    if tty_num and claude_ttys[tty_num] then
      table.insert(claude_panes, pane.id)
    end
  end

  return claude_panes
end

-- Find the Nth Claude pane (1-indexed, defaults to 1)
-- Returns pane_id or nil if not found
function M.find_claude_pane(pane_index)
  pane_index = pane_index or 1

  -- Validate pane index
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

  local claude_panes = M.find_all_claude_panes()

  -- Return the Nth pane if it exists
  if pane_index <= #claude_panes then
    return claude_panes[pane_index], nil
  end

  if #claude_panes == 0 then
    return nil, "No tmux pane with Claude found in current window"
  else
    return nil, string.format("No Claude pane #%d found (only %d pane(s) available)", pane_index, #claude_panes)
  end
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

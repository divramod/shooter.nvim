-- Watch pane management for shooter.nvim
-- Spawns a maximized tmux pane running shooter watch

local M = {}

-- Check if tmux is available
local function check_tmux()
  local result = vim.fn.system('which tmux 2>/dev/null')
  return vim.v.shell_error == 0 and result ~= ''
end

-- Check if we're inside a tmux session
local function in_tmux()
  return vim.env.TMUX ~= nil and vim.env.TMUX ~= ''
end

-- Run tmux command and return output
local function tmux_cmd(cmd)
  local result = vim.fn.system('tmux ' .. cmd .. ' 2>/dev/null') -- audited: deferred follow-up (baseline.md § Phase 004 T008 deferred)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(result)
end

-- Open a new pane with shooter watch, maximized
-- When shooter watch exits, the pane closes and layout is automatically restored
function M.open_watch_pane()
  -- Validate environment
  if not check_tmux() then
    return false
  end

  if not in_tmux() then
    return false
  end

  -- Check if shooter CLI is available
  local shooter_check = vim.fn.system('which shooter 2>/dev/null')
  if vim.v.shell_error ~= 0 or shooter_check == '' then
    return false
  end

  -- Save current layout BEFORE splitting (to restore when watch exits)
  local saved_layout = tmux_cmd('display-message -p "#{window_layout}"')
  if not saved_layout or saved_layout == '' then
    return false
  end

  -- Save layout to temp file to avoid shell quoting issues
  local layout_file = '/tmp/shooter_watch_layout_' .. vim.fn.getpid()
  local f = io.open(layout_file, 'w')
  if f then f:write(saved_layout); f:close() end

  -- Command: run shooter watch, unzoom, then background job restores layout after pane closes
  local cmd = string.format(
    'shooter watch; tmux resize-pane -Z 2>/dev/null; (sleep 0.3; tmux select-layout "$(cat %s)"; rm -f %s) &',
    layout_file, layout_file
  )

  -- Split window vertically (top/bottom) - doesn't affect horizontal pane widths
  local new_pane = tmux_cmd(string.format('split-window -vb -P -F "#{pane_id}" "%s"', cmd))

  if not new_pane or new_pane == '' then
    return false
  end

  -- Zoom the new pane immediately (maximize it)
  vim.fn.system('sleep 0.1')
  tmux_cmd('resize-pane -Z -t ' .. new_pane)

  return true
end

return M

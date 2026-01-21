-- Tmux pane visibility toggle for shooter.nvim
-- Toggle panes in/out of view with <space>r1-4

local M = {}

-- Track hidden panes: { [pane_index] = { window_id = "...", pane_id = "..." } }
local hidden_panes = {}

-- Get current tmux window ID
local function get_current_window()
  local handle = io.popen("tmux display -p '#{window_id}' 2>/dev/null")
  if not handle then return nil end
  local window_id = handle:read("*l")
  handle:close()
  return window_id and window_id ~= "" and window_id or nil
end

-- Get pane ID by index (1-based, left-to-right order)
local function get_pane_id_by_index(index)
  local detect = require('shooter.tmux.detect')
  local panes = detect.list_all_panes()
  if not panes or #panes < index then
    return nil
  end
  return panes[index] and panes[index].id or nil
end

-- Check if a window exists
local function window_exists(window_id)
  local handle = io.popen(string.format(
    "tmux list-windows -F '#{window_id}' 2>/dev/null | grep -q '%s' && echo yes",
    window_id
  ))
  if not handle then return false end
  local result = handle:read("*l")
  handle:close()
  return result == "yes"
end

-- Hide a pane by breaking it to a new window
local function hide_pane(pane_index, pane_id)
  local utils = require('shooter.utils')

  -- Break pane to a new window (stays in background with -d)
  local cmd = string.format("tmux break-pane -d -t %s 2>/dev/null", pane_id)
  local handle = io.popen(cmd)
  if handle then handle:close() end

  -- Get the window that was just created (the broken pane is now in it)
  local win_handle = io.popen("tmux list-windows -F '#{window_id}' 2>/dev/null | tail -1")
  if not win_handle then
    utils.notify('Failed to track hidden pane', vim.log.levels.ERROR)
    return false
  end
  local new_window = win_handle:read("*l")
  win_handle:close()

  -- Store the hidden pane info
  hidden_panes[pane_index] = {
    window_id = new_window,
    original_pane_id = pane_id,
  }

  return true
end

-- Show a hidden pane by joining it back
local function show_pane(pane_index)
  local utils = require('shooter.utils')
  local info = hidden_panes[pane_index]

  if not info or not info.window_id then
    utils.notify('No hidden pane ' .. pane_index .. ' to show', vim.log.levels.WARN)
    return false
  end

  -- Check the hidden window still exists
  if not window_exists(info.window_id) then
    hidden_panes[pane_index] = nil
    utils.notify('Hidden pane window no longer exists', vim.log.levels.WARN)
    return false
  end

  -- Join the pane back (from the hidden window to current window)
  -- -h = horizontal split (pane appears to the left)
  -- -b = before current pane
  local cmd = string.format(
    "tmux join-pane -h -b -s %s 2>/dev/null",
    info.window_id
  )
  local handle = io.popen(cmd)
  if handle then handle:close() end

  -- Clear the hidden state
  hidden_panes[pane_index] = nil

  return true
end

-- Check if a pane index is currently hidden
function M.is_hidden(pane_index)
  return hidden_panes[pane_index] ~= nil
end

-- Toggle pane visibility
function M.toggle(pane_index)
  local utils = require('shooter.utils')
  local detect = require('shooter.tmux.detect')

  -- Check tmux is available
  if not detect.check_tmux_installed() or not detect.in_tmux() then
    utils.notify('Not in tmux', vim.log.levels.WARN)
    return
  end

  -- If pane is hidden, show it
  if M.is_hidden(pane_index) then
    if show_pane(pane_index) then
      utils.notify('Pane ' .. pane_index .. ' shown', vim.log.levels.INFO)
    end
    return
  end

  -- Otherwise, hide the pane at this index
  local pane_id = get_pane_id_by_index(pane_index)
  if not pane_id then
    utils.notify('No pane ' .. pane_index .. ' to hide', vim.log.levels.WARN)
    return
  end

  -- Don't hide the current pane (the one running nvim)
  local current_handle = io.popen("tmux display -p '#{pane_id}' 2>/dev/null")
  if current_handle then
    local current_pane = current_handle:read("*l")
    current_handle:close()
    if current_pane == pane_id then
      utils.notify('Cannot hide current pane', vim.log.levels.WARN)
      return
    end
  end

  if hide_pane(pane_index, pane_id) then
    utils.notify('Pane ' .. pane_index .. ' hidden', vim.log.levels.INFO)
  end
end

-- Get status of all panes (for debugging/help)
function M.get_status()
  local status = {}
  for i = 1, 9 do
    if hidden_panes[i] then
      status[i] = 'hidden'
    end
  end
  return status
end

return M

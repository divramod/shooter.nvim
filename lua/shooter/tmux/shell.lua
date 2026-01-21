-- Shell pane detection for shooter.nvim
-- Find and interact with shell panes (zsh/bash) for Claude startup

local M = {}

-- Get the process running in a specific pane (foreground process)
function M.get_pane_command(pane_id)
  local handle = io.popen(string.format(
    "tmux display -p -t %s '#{pane_current_command}' 2>/dev/null",
    pane_id
  ))
  if not handle then
    return nil
  end
  local cmd = handle:read("*l")
  handle:close()
  return cmd
end

-- Check if a pane is running a shell (zsh or bash)
function M.is_shell_pane(pane_id)
  local cmd = M.get_pane_command(pane_id)
  if not cmd then
    return false
  end
  -- Match zsh, bash, -zsh, -bash (login shells)
  return cmd:match('^%-?[zb]?a?sh$') or cmd:match('^%-?zsh$') or cmd:match('^%-?bash$')
end

-- Find pane to the left of current pane
function M.find_left_pane()
  local detect = require('shooter.tmux.detect')
  if not detect.check_tmux_installed() or not detect.in_tmux() then
    return nil
  end

  -- Get current pane ID
  local handle = io.popen("tmux display -p '#{pane_id}' 2>/dev/null")
  if not handle then
    return nil
  end
  local current_pane = handle:read("*l")
  handle:close()

  -- Get pane to the left
  local left_handle = io.popen(string.format(
    "tmux select-pane -L -t %s 2>/dev/null && tmux display -p '#{pane_id}' && tmux select-pane -R",
    current_pane
  ))
  if not left_handle then
    return nil
  end
  local left_pane = left_handle:read("*l")
  left_handle:close()

  -- If we got the same pane, there's no left pane
  if left_pane == current_pane or not left_pane or left_pane == "" then
    return nil
  end

  return left_pane
end

-- Find a shell pane (zsh/bash) in current window, preferring left pane
function M.find_shell_pane()
  local detect = require('shooter.tmux.detect')

  -- First check the left pane
  local left_pane = M.find_left_pane()
  if left_pane and M.is_shell_pane(left_pane) then
    return left_pane
  end

  -- Otherwise check all panes for a shell
  local panes = detect.list_all_panes()
  for _, pane in ipairs(panes) do
    if M.is_shell_pane(pane.id) then
      return pane.id
    end
  end

  return nil
end

return M

-- Tmux pane creation for shooter.nvim
-- Auto-create tmux panes with Claude

local utils = require('shooter.utils')
local detect = require('shooter.tmux.detect')
local shell = require('shooter.tmux.shell')

local M = {}

-- Claude command with continue and skip-permissions flags
local CLAUDE_CMD = 'claude -c --dangerously-skip-permissions'

-- Start Claude in an existing shell pane
-- Sends Ctrl-C first to handle vi mode and clear any pending input
-- Returns true on success, false on failure
function M.start_claude_in_pane(pane_id)
  if not pane_id then
    return false, "No pane ID provided"
  end
  -- Send Ctrl-C to cancel any pending input (handles vi normal mode too)
  -- Then Ctrl-U to clear the line, then the command
  os.execute(string.format("tmux send-keys -t %s C-c C-u 2>/dev/null", pane_id))
  vim.wait(100, function() return false end, 20)  -- Brief pause for shell to process
  os.execute(string.format("tmux send-keys -t %s '%s' Enter 2>/dev/null", pane_id, CLAUDE_CMD))
  return true, nil
end

-- Create a new pane to the left
-- Returns pane_id on success, nil and error message on failure
function M.create_left_pane()
  if not detect.check_tmux_installed() then
    return nil, "tmux is not installed"
  end
  if not detect.in_tmux() then
    return nil, "Not running in tmux"
  end

  -- Create pane to the left with 50% width
  local handle = io.popen("tmux split-window -hb -p 50 -P -F '#{pane_id}' 2>/dev/null")
  if not handle then
    return nil, "Failed to create tmux pane"
  end
  local pane_id = handle:read("*l")
  handle:close()

  if not pane_id or pane_id == "" then
    return nil, "Failed to get new pane ID"
  end
  return pane_id, nil
end

-- Create a new pane to the left and start Claude
-- Returns pane_id on success, nil and error message on failure
function M.create_claude_pane()
  local pane_id, err = M.create_left_pane()
  if not pane_id then
    return nil, err
  end
  M.start_claude_in_pane(pane_id)
  return pane_id, nil
end

-- Check if a pane is running Claude (by checking foreground process)
function M.is_pane_running_claude(pane_id)
  local cmd = shell.get_pane_command(pane_id)
  if not cmd then
    return false
  end
  -- Match "claude", "node", or version pattern like "2.1.14"
  -- Claude sets its process title to its version number
  return cmd:match('^claude')
    or cmd:match('^node')
    or cmd:match('^%d+%.%d+')  -- Version pattern: 2.1.14, 3.0.0, etc.
end

-- Wait for Claude to be ready in a pane (check foreground process)
-- Uses vim.wait() which keeps nvim responsive during the wait
-- Returns true when ready, false on timeout
function M.wait_for_claude(pane_id, timeout_ms)
  timeout_ms = timeout_ms or 10000  -- Default 10 seconds

  -- vim.wait() keeps nvim responsive while polling
  local ok = vim.wait(timeout_ms, function()
    return M.is_pane_running_claude(pane_id)
  end, 500)  -- Check every 500ms

  return ok
end

-- Start Claude in a pane and wait for it to be ready
-- Returns pane_id on success, nil and error on failure
function M.start_and_wait_for_claude(pane_id, message)
  utils.echo(message or "Starting Claude...")
  M.start_claude_in_pane(pane_id)
  utils.echo("Waiting for Claude to start...")

  if M.wait_for_claude(pane_id, 15000) then
    -- Give Claude time to fully initialize and show prompt
    -- Use vim.wait with always-false condition for non-blocking delay
    vim.wait(3000, function() return false end, 100)
    utils.echo("Claude is ready")
    return pane_id, nil
  else
    return nil, "Claude did not start within timeout"
  end
end

-- Find or create Claude pane at index, creating if needed
-- Strategy: 1. Find existing Claude pane
--           2. Find shell pane (zsh/bash) and start Claude there
--           3. Create new pane and start Claude
-- Returns pane_id, nil on success; nil, error on failure
function M.find_or_create_claude_pane(pane_index)
  pane_index = pane_index or 1

  -- First try to find existing Claude pane
  local pane_id, err = detect.find_claude_pane(pane_index)
  if pane_id then
    return pane_id, nil
  end

  -- If no Claude pane found, try to find a shell pane to start Claude in
  if err and err:match("No tmux pane with Claude found") then
    local shell_pane = shell.find_shell_pane()

    if shell_pane then
      -- Found a shell pane - start Claude there
      return M.start_and_wait_for_claude(shell_pane, "Starting Claude in shell pane...")
    else
      -- No shell pane found - create a new pane
      utils.echo("Creating pane for Claude...")
      local new_pane_id, create_err = M.create_left_pane()
      if not new_pane_id then
        return nil, create_err
      end
      -- Wait for shell to initialize in new pane (non-blocking)
      vim.wait(500, function() return false end, 50)
      return M.start_and_wait_for_claude(new_pane_id, "Starting Claude in new pane...")
    end
  end

  return nil, err
end

return M

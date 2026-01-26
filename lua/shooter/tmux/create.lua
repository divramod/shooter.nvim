-- Tmux pane creation for shooter.nvim
-- Auto-create tmux panes with AI (Claude or opencode)

local utils = require('shooter.utils')
local detect = require('shooter.tmux.detect')
local shell = require('shooter.tmux.shell')

local M = {}

-- Provider commands (continue session + skip permissions where available)
local PROVIDER_CMDS = {
  claude = 'claude -c --dangerously-skip-permissions',
  opencode = 'opencode -c',
}

-- Start AI in an existing shell pane
-- Sends Ctrl-C first to handle vi mode and clear any pending input
-- Returns true on success, false on failure
function M.start_ai_in_pane(pane_id, provider_name)
  if not pane_id then
    return false, "No pane ID provided"
  end
  provider_name = provider_name or 'claude'
  local cmd = PROVIDER_CMDS[provider_name] or PROVIDER_CMDS.claude
  -- Send Ctrl-C to cancel any pending input (handles vi normal mode too)
  -- Then Ctrl-U to clear the line, then the command
  os.execute(string.format("tmux send-keys -t %s C-c C-u 2>/dev/null", pane_id))
  vim.wait(100, function() return false end, 20)  -- Brief pause for shell to process
  os.execute(string.format("tmux send-keys -t %s '%s' Enter 2>/dev/null", pane_id, cmd))
  return true, nil
end

-- Backward compatibility alias
function M.start_claude_in_pane(pane_id)
  return M.start_ai_in_pane(pane_id, 'claude')
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

-- Check if a pane is running an AI (by checking it's no longer a shell)
-- When AI starts, it replaces the shell process
function M.is_pane_running_ai(pane_id)
  local cmd = shell.get_pane_command(pane_id)
  if not cmd then return false end
  if shell.is_shell_pane(pane_id) then return false end
  return true
end

-- Backward compatibility alias
M.is_pane_running_claude = M.is_pane_running_ai

-- Wait for AI to be ready in a pane (check foreground process)
function M.wait_for_ai(pane_id, timeout_ms)
  timeout_ms = timeout_ms or 10000
  return vim.wait(timeout_ms, function()
    return M.is_pane_running_ai(pane_id)
  end, 500)
end

-- Backward compatibility alias
M.wait_for_claude = M.wait_for_ai

-- Start AI in a pane and wait for it to be ready
function M.start_and_wait_for_ai(pane_id, provider_name, message)
  provider_name = provider_name or 'claude'
  local display_name = provider_name == 'opencode' and 'OpenCode' or 'Claude'
  utils.echo(message or string.format("Starting %s...", display_name))
  M.start_ai_in_pane(pane_id, provider_name)
  utils.echo(string.format("Waiting for %s to start...", display_name))

  if M.wait_for_ai(pane_id, 15000) then
    vim.wait(5000, function() return false end, 100)
    utils.echo(string.format("%s is ready", display_name))
    return pane_id, nil
  else
    return nil, string.format("%s did not start within timeout", display_name)
  end
end

-- Backward compatibility alias
function M.start_and_wait_for_claude(pane_id, message)
  return M.start_and_wait_for_ai(pane_id, 'claude', message)
end

-- Prompt user to select which AI provider to start
-- Returns provider name ('claude' or 'opencode') or nil if cancelled
function M.prompt_provider_selection()
  local choice = vim.fn.confirm(
    'No AI session found. Which AI do you want to start?',
    '&Claude\n&OpenCode\n&Cancel',
    1
  )
  if choice == 1 then return 'claude' end
  if choice == 2 then return 'opencode' end
  return nil
end

-- Start AI in a pane (shell or new), with provider selection
function M.start_ai_with_prompt(pane_index)
  local provider = M.prompt_provider_selection()
  if not provider then
    return nil, "Cancelled"
  end

  local display_name = provider == 'opencode' and 'OpenCode' or 'Claude'
  local shell_pane = shell.find_shell_pane()

  if shell_pane then
    return M.start_and_wait_for_ai(shell_pane, provider,
      string.format("Starting %s in shell pane...", display_name))
  else
    utils.echo(string.format("Creating pane for %s...", display_name))
    local new_pane_id, create_err = M.create_left_pane()
    if not new_pane_id then
      return nil, create_err
    end
    vim.wait(500, function() return false end, 50)
    return M.start_and_wait_for_ai(new_pane_id, provider,
      string.format("Starting %s in new pane...", display_name))
  end
end

-- Find or create Claude pane at index (backward compat, always starts Claude)
function M.find_or_create_claude_pane(pane_index)
  pane_index = pane_index or 1
  local pane_id, err = detect.find_claude_pane(pane_index)
  if pane_id then return pane_id, nil end

  if err and err:match("No tmux pane with") then
    local shell_pane = shell.find_shell_pane()
    if shell_pane then
      return M.start_and_wait_for_ai(shell_pane, 'claude', "Starting Claude in shell pane...")
    else
      utils.echo("Creating pane for Claude...")
      local new_pane_id, create_err = M.create_left_pane()
      if not new_pane_id then return nil, create_err end
      vim.wait(500, function() return false end, 50)
      return M.start_and_wait_for_ai(new_pane_id, 'claude', "Starting Claude in new pane...")
    end
  end
  return nil, err
end

-- Find existing AI pane or prompt user to create one
-- Returns pane_id, nil on success; nil, error on failure
function M.find_or_create_ai_pane(pane_index)
  pane_index = pane_index or 1

  -- First try to find existing AI pane (Claude or opencode)
  local pane_id, err = detect.find_ai_pane(pane_index)
  if pane_id then
    return pane_id, nil
  end

  -- No AI pane found - prompt user to select which AI to start
  if err and err:match("No tmux pane with") then
    return M.start_ai_with_prompt(pane_index)
  end

  return nil, err
end

return M

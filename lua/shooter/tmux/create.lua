-- Tmux pane creation for shooter.nvim
-- Auto-create tmux panes with Claude

local utils = require('shooter.utils')
local detect = require('shooter.tmux.detect')

local M = {}

-- Create a new pane to the left and start Claude
-- Returns pane_id on success, nil and error message on failure
function M.create_claude_pane()
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

  -- Start Claude in the new pane
  os.execute(string.format("tmux send-keys -t %s 'claude' Enter 2>/dev/null", pane_id))

  return pane_id, nil
end

-- Wait for Claude to be ready in a pane (check for process)
-- Returns true when ready, false on timeout
function M.wait_for_claude(pane_id, timeout_ms)
  timeout_ms = timeout_ms or 10000  -- Default 10 seconds
  local start = vim.loop.now()

  while (vim.loop.now() - start) < timeout_ms do
    -- Get the TTY of the pane
    local handle = io.popen(string.format("tmux display -p -t %s '#{pane_tty}' 2>/dev/null", pane_id))
    if handle then
      local tty = handle:read("*l")
      handle:close()

      if tty then
        local tty_num = tty:match("ttys(%d+)")
        if tty_num then
          -- Check if Claude is running on this TTY
          -- macOS ps shows "s009" format, tmux shows "/dev/ttys009"
          -- So grep for anything ending in "s" + tty_num (matches s009, ttys009)
          local ps_handle = io.popen(string.format(
            "ps aux | grep '[c]laude' | awk '{print $7}' | grep -q 's%s$' && echo 'yes'",
            tty_num
          ))
          if ps_handle then
            local result = ps_handle:read("*l")
            ps_handle:close()
            if result == "yes" then
              return true
            end
          end
        end
      end
    end

    -- Wait a bit before checking again
    vim.loop.sleep(500)
  end

  return false
end

-- Find or create Claude pane at index, creating if needed
-- Returns pane_id, nil on success; nil, error on failure
function M.find_or_create_claude_pane(pane_index)
  pane_index = pane_index or 1

  -- First try to find existing pane
  local pane_id, err = detect.find_claude_pane(pane_index)
  if pane_id then
    return pane_id, nil
  end

  -- If no Claude pane found at all, create one
  if err and err:match("No tmux pane with Claude found") then
    utils.echo("Creating Claude pane...")

    local new_pane_id, create_err = M.create_claude_pane()
    if not new_pane_id then
      return nil, create_err
    end

    utils.echo("Waiting for Claude to start...")

    if M.wait_for_claude(new_pane_id, 15000) then
      -- Give Claude a moment to fully initialize
      vim.loop.sleep(1000)
      utils.echo("Claude is ready")
      return new_pane_id, nil
    else
      return nil, "Claude did not start within timeout"
    end
  end

  return nil, err
end

return M

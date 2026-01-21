-- Send text via tmux send-keys for shooter.nvim
-- This mode shows full text in shell history instead of "[pasted N lines]"

local M = {}

-- Escape text for shell single-quoted string
local function shell_escape(text)
  -- In single quotes, only ' needs escaping as '\''
  return text:gsub("'", "'\\''")
end

-- Send text using send-keys (shows in shell history)
-- This is slower than paste-buffer but the text appears in command history
function M.send(pane_id, text)
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  if not f then
    return false, "Failed to create temp file"
  end

  -- Build script: send each line with send-keys -l
  local lines = vim.split(text, '\n', { plain = true })
  local script_parts = {}

  -- Initial escape sequence to ensure clean state
  table.insert(script_parts, string.format("tmux send-keys -t %s Escape Escape i", pane_id))
  table.insert(script_parts, "sleep 0.05")

  for i, line in ipairs(lines) do
    local escaped = shell_escape(line)
    table.insert(script_parts, string.format("tmux send-keys -t %s -l '%s'", pane_id, escaped))
    -- Send Enter after each line except last (to create newlines)
    if i < #lines then
      table.insert(script_parts, string.format("tmux send-keys -t %s Enter", pane_id))
    end
  end

  -- Final Enter to submit the command
  table.insert(script_parts, "sleep 0.1")
  table.insert(script_parts, string.format("tmux send-keys -t %s Enter", pane_id))
  table.insert(script_parts, "sleep 0.1")
  table.insert(script_parts, string.format("tmux send-keys -t %s Enter", pane_id))

  local script = table.concat(script_parts, "\n")
  f:write("#!/bin/bash\n")
  f:write(script)
  f:close()

  local success = os.execute("bash " .. tmpfile)
  os.remove(tmpfile)

  if success == 0 or success == true then
    return true, nil
  else
    return false, "send-keys failed"
  end
end

return M

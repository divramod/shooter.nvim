-- Codex provider for shooter.nvim
-- Handles detection and communication with Codex CLI

local M = {}

local function shell_escape(text)
  return text:gsub("'", "'\\''")
end

-- Provider identity
M.name = 'codex'
M.display_name = 'Codex'
M.process_pattern = 'codex'

-- Send file path to pane (literal path, no @ prefix)
function M.send_file_reference(pane_id, filepath)
  if not pane_id or pane_id == "" then
    return false, "No pane ID provided"
  end
  if not filepath or filepath == "" then
    return false, "No filepath provided"
  end

  -- Codex can stall on @filepath; send literal path and submit.
  local escaped_path = shell_escape(filepath)
  local cmd = string.format(
    "tmux send-keys -t %s C-u && sleep 0.1 && tmux send-keys -t %s -l '%s' && sleep 0.1 && tmux send-keys -t %s Enter && sleep 0.1 && tmux send-keys -t %s Enter",
    pane_id, pane_id, escaped_path, pane_id, pane_id
  )

  local job_id = vim.fn.jobstart({"sh", "-c", cmd .. " 2>/dev/null"}, {
    stdout_buffered = true,
    stderr_buffered = true,
  })
  if job_id <= 0 then return false, "Failed to start tmux job" end
  local result = vim.fn.jobwait({job_id}, 30000)
  if result[1] == 0 then
    return true, nil
  end
  return false, "tmux command failed"
end

-- Send raw text to pane
function M.send_text(pane_id, text)
  local send = require('shooter.tmux.send')
  return send.send_to_pane(pane_id, text)
end

-- Build message for shots (uses standard shooter messages)
function M.build_shot_message(bufnr, shot_info)
  local messages = require('shooter.tmux.messages')
  return messages.build_shot_message(bufnr, shot_info)
end

-- Build message for multiple shots
function M.build_multishot_message(bufnr, shot_infos)
  local messages = require('shooter.tmux.messages')
  return messages.build_multishot_message(bufnr, shot_infos)
end

-- Provider-specific pane creation command
function M.get_create_command()
  return 'codex'
end

-- Check if this provider can handle interactive creation
function M.supports_auto_create()
  return true
end

return M

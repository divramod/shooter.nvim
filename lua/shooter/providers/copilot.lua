-- Copilot provider for shooter.nvim
-- Handles detection and communication with GitHub Copilot CLI

local M = {}

-- Provider identity
M.name = 'copilot'
M.display_name = 'Copilot'
M.process_pattern = 'copilot'

-- Send file reference to pane
-- Copilot's @ triggers autocomplete, so dismiss it before submitting
function M.send_file_reference(pane_id, filepath)
  if not pane_id or pane_id == "" then
    return false, "No pane ID provided"
  end
  if not filepath or filepath == "" then
    return false, "No filepath provided"
  end

  local cmd = string.format(
    "tmux send-keys -t %s C-u && sleep 0.1 && tmux send-keys -t %s -l '@%s' && sleep 0.3 && tmux send-keys -t %s Escape && sleep 0.1 && tmux send-keys -t %s Enter",
    pane_id, pane_id, filepath, pane_id, pane_id
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
  return 'copilot'
end

-- Check if this provider can handle interactive creation
function M.supports_auto_create()
  return true
end

return M

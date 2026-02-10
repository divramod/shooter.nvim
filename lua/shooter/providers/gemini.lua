-- Gemini provider for shooter.nvim
-- Handles detection and communication with Gemini CLI

local M = {}

-- Provider identity
M.name = 'gemini'
M.display_name = 'Gemini'
M.process_pattern = 'gemini'

-- Send shot file content directly to pane
function M.send_file_reference(pane_id, filepath)
  if not pane_id or pane_id == "" then
    return false, "No pane ID provided"
  end
  if not filepath or filepath == "" then
    return false, "No filepath provided"
  end

  local utils = require('shooter.utils')
  local content, err = utils.read_file(filepath)
  if not content then
    return false, "Failed to read file: " .. (err or "unknown error")
  end

  -- Keep Gemini running; clear input line but avoid Ctrl-C.
  local clear_job = vim.fn.jobstart({"tmux", "send-keys", "-t", pane_id, "C-u"}, {
    stdout_buffered = true,
    stderr_buffered = true,
  })
  if clear_job > 0 then vim.fn.jobwait({clear_job}, 5000) end
  vim.wait(100, function() return false end, 20)

  local send = require('shooter.tmux.send')
  return send.send_to_pane(pane_id, content, nil, false)
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
  return 'gemini'
end

-- Check if this provider can handle interactive creation
function M.supports_auto_create()
  return true
end

return M

-- Claude Code provider for shooter.nvim
-- Handles detection and communication with Claude CLI

local M = {}

-- Provider identity
M.name = 'claude'
M.display_name = 'Claude'
M.process_pattern = 'claude'

-- Send file reference to pane (@filepath syntax)
function M.send_file_reference(pane_id, filepath)
  local send = require('shooter.tmux.send')
  return send.send_file_reference(pane_id, filepath)
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
  return 'claude'
end

-- Check if this provider can handle interactive creation
function M.supports_auto_create()
  return true
end

return M

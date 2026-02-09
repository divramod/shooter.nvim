-- Codex provider for shooter.nvim
-- Handles detection and communication with Codex CLI

local M = {}

local function resolve_workspace_file(filepath)
  local files = require('shooter.core.files')
  local utils = require('shooter.utils')

  local git_root = files.get_git_root()
  if not git_root then
    return filepath, nil
  end

  local root_abs = vim.fn.fnamemodify(git_root, ':p')
  local file_abs = vim.fn.fnamemodify(filepath, ':p')
  local root_prefix = root_abs:sub(-1) == '/' and root_abs or (root_abs .. '/')

  -- Codex can hang on @file references outside the workspace; copy those in.
  if file_abs:find(root_prefix, 1, true) == 1 then
    return file_abs, nil
  end

  local workspace_dir = root_prefix .. '.shooter.nvim/bullets'
  local workspace_file = workspace_dir .. '/' .. vim.fn.fnamemodify(file_abs, ':t')
  local content, read_err = utils.read_file(file_abs)
  if not content then
    return nil, read_err or 'Failed to read source file'
  end

  utils.ensure_dir(workspace_dir)
  local ok, write_err = utils.write_file(workspace_file, content)
  if not ok then
    return nil, write_err or 'Failed to write workspace copy'
  end

  return workspace_file, nil
end

-- Provider identity
M.name = 'codex'
M.display_name = 'Codex'
M.process_pattern = 'codex'

-- Send file reference to pane (@filepath syntax)
function M.send_file_reference(pane_id, filepath)
  local resolved, err = resolve_workspace_file(filepath)
  if not resolved then
    return false, 'Failed to prepare file reference: ' .. (err or 'unknown error')
  end

  local send = require('shooter.tmux.send')
  return send.send_file_reference(pane_id, resolved)
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

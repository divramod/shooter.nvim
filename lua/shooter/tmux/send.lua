-- Send text to tmux panes for shooter.nvim
-- Handle text transmission and escape sequences

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Prepare escape sequences for tmux send-keys
-- Returns a command string with all necessary escape sequences
function M.prepare_escape_sequences(pane_id)
  -- Sequence to ensure clean state:
  -- 1. Multiple Escapes to exit vim/insert mode if active
  -- 2. C-c to cancel any command
  -- 3. C-u to clear prompt line
  -- 4. Escape Escape i (handle copy mode + ensure insert mode)
  local cmd_parts = {
    string.format("tmux send-keys -t %s Escape Escape Escape", pane_id),
    "sleep 0.1",
    string.format("tmux send-keys -t %s C-c", pane_id),
    "sleep 0.1",
    string.format("tmux send-keys -t %s C-u", pane_id),
    "sleep 0.1",
    string.format("tmux send-keys -t %s Escape Escape i", pane_id),
    "sleep 0.1",
  }
  return table.concat(cmd_parts, " && ")
end

-- Calculate appropriate delay based on text characteristics
function M.calculate_delay(text)
  local text_length = #text
  local line_count = select(2, text:gsub('\n', '\n')) + 1

  local threshold_chars = config.get('tmux.long_message_threshold')
  local threshold_lines = config.get('tmux.long_message_lines')
  local base_delay = config.get('tmux.delay')
  local long_delay = config.get('tmux.long_delay')

  -- Long message
  if line_count > threshold_lines or text_length > threshold_chars then
    return long_delay
  end

  -- Medium message
  if line_count > 20 or text_length > 2000 then
    return 1.0
  end

  -- Short-medium message
  if line_count > 5 or text_length > 500 then
    return 0.5
  end

  -- Short message
  return base_delay
end

-- Calculate delay for multishot messages (always longer)
function M.calculate_multishot_delay(text)
  local text_length = #text
  local line_count = select(2, text:gsub('\n', '\n')) + 1

  -- Very long multishot
  if line_count > 100 or text_length > 10000 then
    return 2.5
  end

  -- Default multishot delay
  return 1.5
end

-- Execute tmux command with error handling
function M.execute_tmux_command(cmd)
  local result = os.execute(cmd)
  if result == 0 or result == true then
    return true, nil
  else
    return false, "tmux command failed"
  end
end

-- Write text to temporary file
-- Returns tmpfile path or nil on error
function M.write_to_tempfile(text)
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  if not f then
    return nil, "Failed to create temp file"
  end
  f:write(text)
  f:close()
  return tmpfile, nil
end

-- Build tmux send command
function M.build_send_command(pane_id, tmpfile, delay, include_escape_prep)
  include_escape_prep = include_escape_prep == nil and true or include_escape_prep

  local cmd_parts = {}

  -- Optional: Add escape sequence preparation
  if include_escape_prep then
    table.insert(cmd_parts, M.prepare_escape_sequences(pane_id))
  end

  -- Load buffer and paste
  table.insert(cmd_parts, string.format("tmux load-buffer %s", tmpfile))
  table.insert(cmd_parts, string.format("tmux paste-buffer -t %s", pane_id))
  table.insert(cmd_parts, string.format("sleep %.1f", delay))

  -- Send Enter twice (once to complete any pending action, once to submit)
  table.insert(cmd_parts, string.format("tmux send-keys -t %s Enter", pane_id))
  table.insert(cmd_parts, "sleep 0.1")
  table.insert(cmd_parts, string.format("tmux send-keys -t %s Enter", pane_id))

  -- Cleanup temp file
  table.insert(cmd_parts, string.format("rm %s", tmpfile))

  return table.concat(cmd_parts, " && ")
end

-- Send text to a specific pane
-- Returns success, error message, text_length
function M.send_to_pane(pane_id, text, delay, include_escape_prep)
  -- Validate inputs
  if not pane_id or pane_id == "" then
    return false, "No pane ID provided", 0
  end

  if not text or text == "" or text:match('^%s*$') then
    return false, "No text to send", 0
  end

  -- Calculate delay if not provided
  delay = delay or M.calculate_delay(text)
  include_escape_prep = include_escape_prep == nil and true or include_escape_prep

  -- Write to temp file
  local tmpfile, err = M.write_to_tempfile(text)
  if not tmpfile then
    return false, err, 0
  end

  -- Build and execute command
  local cmd = M.build_send_command(pane_id, tmpfile, delay, include_escape_prep)
  local success, cmd_err = M.execute_tmux_command(cmd)

  if not success then
    -- Clean up temp file on error
    os.remove(tmpfile)
    return false, cmd_err, 0
  end

  local text_length = #text
  return true, nil, text_length
end

-- Send multishot text (uses different delay calculation)
function M.send_multishot_to_pane(pane_id, text)
  if not text or text == "" or text:match('^%s*$') then
    return false, "No text to send", 0
  end

  local delay = M.calculate_multishot_delay(text)

  -- For multishot, we skip the escape prep (assume clean state)
  -- Multishot uses simpler sequence: Escape Escape i -> paste -> Enter twice
  local tmpfile, err = M.write_to_tempfile(text)
  if not tmpfile then
    return false, err, 0
  end

  -- Simpler command for multishot
  local cmd = string.format(
    "tmux send-keys -t %s Escape Escape i && sleep 0.1 && tmux load-buffer %s && tmux paste-buffer -t %s && sleep %.1f && tmux send-keys -t %s Enter && sleep 0.1 && tmux send-keys -t %s Enter && rm %s",
    pane_id, tmpfile, pane_id, delay, pane_id, pane_id, tmpfile
  )

  local success, cmd_err = M.execute_tmux_command(cmd)

  if not success then
    os.remove(tmpfile)
    return false, cmd_err, 0
  end

  local text_length = #text
  return true, nil, text_length
end

return M

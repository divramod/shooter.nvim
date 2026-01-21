-- Send text to tmux panes for shooter.nvim
-- Handle text transmission and escape sequences

local config = require('shooter.config')
local keys = require('shooter.tmux.keys')

local M = {}

-- Prepare escape sequences for tmux send-keys
-- For Claude Code prompt (not vim editing)
function M.prepare_escape_sequences(pane_id)
  local cmd_parts = {
    -- Cancel any operation and clear line
    string.format("tmux send-keys -t %s C-c", pane_id),
    "sleep 0.05",
    string.format("tmux send-keys -t %s C-u", pane_id),
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

  if line_count > threshold_lines or text_length > threshold_chars then
    return long_delay
  end
  if line_count > 20 or text_length > 2000 then
    return 1.0
  end
  if line_count > 5 or text_length > 500 then
    return 0.5
  end
  return base_delay
end

-- Calculate delay for multishot messages
function M.calculate_multishot_delay(text)
  local text_length = #text
  local line_count = select(2, text:gsub('\n', '\n')) + 1
  if line_count > 100 or text_length > 10000 then
    return 2.5
  end
  return 1.5
end

-- Execute tmux command with error handling
function M.execute_tmux_command(cmd)
  local result = os.execute(cmd)
  if result == 0 or result == true then
    return true, nil
  end
  return false, "tmux command failed"
end

-- Write text to temporary file
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

-- Build tmux send command (paste mode)
function M.build_send_command(pane_id, tmpfile, delay, include_escape_prep)
  include_escape_prep = include_escape_prep == nil and true or include_escape_prep
  local cmd_parts = {}

  if include_escape_prep then
    table.insert(cmd_parts, M.prepare_escape_sequences(pane_id))
  end

  table.insert(cmd_parts, string.format("tmux load-buffer %s", tmpfile))
  -- Use -p for bracketed paste mode (tells terminal this is one paste unit)
  table.insert(cmd_parts, string.format("tmux paste-buffer -p -t %s", pane_id))
  -- Longer delay to ensure paste completes before Enter
  table.insert(cmd_parts, string.format("sleep %.1f", math.max(delay, 1.0)))
  table.insert(cmd_parts, string.format("tmux send-keys -t %s Enter", pane_id))
  table.insert(cmd_parts, "sleep 0.2")
  table.insert(cmd_parts, string.format("tmux send-keys -t %s Enter", pane_id))
  table.insert(cmd_parts, string.format("rm %s", tmpfile))

  return table.concat(cmd_parts, " && ")
end

-- Send text to a specific pane
function M.send_to_pane(pane_id, text, delay, include_escape_prep)
  if not pane_id or pane_id == "" then
    return false, "No pane ID provided", 0
  end
  if not text or text == "" or text:match('^%s*$') then
    return false, "No text to send", 0
  end

  local text_length = #text
  local send_mode = config.get('tmux.send_mode') or 'paste'

  -- Use send-keys mode (shows in shell history)
  if send_mode == 'keys' then
    local success, err = keys.send(pane_id, text)
    return success, err, text_length
  end

  -- Default: paste mode (fast but shows "[pasted]" in history)
  delay = delay or M.calculate_delay(text)
  include_escape_prep = include_escape_prep == nil and true or include_escape_prep

  local tmpfile, err = M.write_to_tempfile(text)
  if not tmpfile then
    return false, err, 0
  end

  local cmd = M.build_send_command(pane_id, tmpfile, delay, include_escape_prep)
  local success, cmd_err = M.execute_tmux_command(cmd)

  if not success then
    os.remove(tmpfile)
    return false, cmd_err, 0
  end
  return true, nil, text_length
end

-- Send multishot text
function M.send_multishot_to_pane(pane_id, text)
  if not text or text == "" or text:match('^%s*$') then
    return false, "No text to send", 0
  end

  local text_length = #text
  local send_mode = config.get('tmux.send_mode') or 'paste'

  if send_mode == 'keys' then
    local success, err = keys.send(pane_id, text)
    return success, err, text_length
  end

  local delay = M.calculate_multishot_delay(text)
  local tmpfile, err = M.write_to_tempfile(text)
  if not tmpfile then
    return false, err, 0
  end

  local actual_delay = math.max(delay, 1.5)
  local cmd = string.format(
    "tmux send-keys -t %s C-c && sleep 0.1 && tmux send-keys -t %s C-u && sleep 0.2 && tmux load-buffer %s && tmux paste-buffer -p -t %s && sleep %.1f && tmux send-keys -t %s Enter && sleep 0.2 && tmux send-keys -t %s Enter && rm %s",
    pane_id, pane_id, tmpfile, pane_id, actual_delay, pane_id, pane_id, tmpfile
  )

  local success, cmd_err = M.execute_tmux_command(cmd)
  if not success then
    os.remove(tmpfile)
    return false, cmd_err, 0
  end
  return true, nil, text_length
end

return M

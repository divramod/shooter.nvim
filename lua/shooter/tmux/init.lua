-- Tmux integration module for shooter.nvim
-- Main entry point for tmux functionality

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Lazy load submodules
M.detect = require('shooter.tmux.detect')
M.send = require('shooter.tmux.send')
M.messages = require('shooter.tmux.messages')

-- Send current shot to Claude pane
function M.send_current_shot(pane_index)
  pane_index = pane_index or 1

  local files = require('shooter.core.files')
  local shots = require('shooter.core.shots')
  local history = require('shooter.history')

  -- Check if we're in a shooter file
  if not files.is_shooter_file() then
    -- Not in shooter file: just send current line
    local text = utils.get_current_line()
    local pane_id = M.detect.find_claude_pane(pane_index)
    if not pane_id then
      utils.echo('No claude pane found')
      return
    end
    M.send.send_to_pane(pane_id, text)
    return
  end

  -- In shooter file: send entire shot with context
  local bufnr = utils.current_buf()
  local cursor_line = utils.get_cursor()[1]
  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, cursor_line)

  if not shot_start then
    utils.echo('No shot found at cursor position')
    return
  end

  -- Get shot info
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text)
  local shot_content = shots.get_shot_content(bufnr, shot_start, shot_end)

  -- Build the full message
  local shot_info = {
    start_line = shot_start,
    end_line = shot_end,
    header_line = header_line,
  }
  local full_message = M.messages.build_shot_message(bufnr, shot_info)

  -- Find the claude pane
  local pane_id = M.detect.find_claude_pane(pane_index)
  if not pane_id then
    local msg = pane_index == 1
      and 'No tmux pane with claude found'
      or string.format('No claude pane #%d found', pane_index)
    utils.echo(msg)
    return
  end

  -- Send to Claude
  local success, err, text_length = M.send.send_to_pane(pane_id, full_message)

  if success then
    -- Mark shot as executed
    shots.mark_shot_executed(bufnr, header_line)

    -- Save to history
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    history.save_shot(shot_content, full_message, shot_num, filepath)

    local pane_msg = pane_index == 1 and '' or string.format(' #%d', pane_index)
    utils.echo(string.format('Sent shot %s to claude%s (%d chars)', shot_num, pane_msg, text_length))
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send all open shots to Claude pane
function M.send_all_shots(pane_index)
  pane_index = pane_index or 1

  local files = require('shooter.core.files')
  local shots = require('shooter.core.shots')
  local history = require('shooter.history')

  if not files.is_shooter_file() then
    utils.echo('Multishot only works in shooter files')
    return
  end

  local bufnr = utils.current_buf()
  local open_shots = shots.find_open_shots(bufnr)

  if #open_shots == 0 then
    utils.echo('No open shots found')
    return
  end

  -- Build multishot message
  local full_message = M.messages.build_multishot_message(bufnr, open_shots)

  -- Find claude pane
  local pane_id = M.detect.find_claude_pane(pane_index)
  if not pane_id then
    local msg = pane_index == 1
      and 'No tmux pane with claude found'
      or string.format('No claude pane #%d found', pane_index)
    utils.echo(msg)
    return
  end

  -- Send to Claude
  local success, err, text_length = M.send.send_multishot_to_pane(pane_id, full_message)

  if success then
    -- Mark all shots as executed and save to history
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    for _, shot_info in ipairs(open_shots) do
      shots.mark_shot_executed(bufnr, shot_info.header_line)

      -- Save each shot to history
      local header_text = utils.get_buf_lines(bufnr, shot_info.header_line - 1, shot_info.header_line)[1]
      local shot_num = shots.parse_shot_header(header_text)
      local shot_content = shots.get_shot_content(bufnr, shot_info.start_line, shot_info.end_line)
      history.save_shot(shot_content, full_message, shot_num, filepath)
    end

    local pane_msg = pane_index == 1 and '' or string.format(' #%d', pane_index)
    utils.echo(string.format('Sent %d shots to claude%s (%d chars)', #open_shots, pane_msg, text_length))
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send visual selection to Claude pane
function M.send_visual_selection(pane_index, start_line, end_line)
  pane_index = pane_index or 1

  local bufnr = utils.current_buf()
  local lines = utils.get_buf_lines(bufnr, start_line - 1, end_line)
  local text = table.concat(lines, '\n')

  if not text or text == '' or text:match('^%s*$') then
    utils.echo('No text selected')
    return
  end

  -- Find claude pane
  local pane_id = M.detect.find_claude_pane(pane_index)
  if not pane_id then
    local msg = pane_index == 1
      and 'No tmux pane with claude found'
      or string.format('No claude pane #%d found', pane_index)
    utils.echo(msg)
    return
  end

  -- Send to Claude (visual selection doesn't mark shots or save history)
  local success, err, text_length = M.send.send_to_pane(pane_id, text)

  if success then
    local pane_msg = pane_index == 1 and '' or string.format(' #%d', pane_index)
    utils.echo(string.format('Sent selection to claude%s (%d chars)', pane_msg, text_length))
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

return M

-- High-level tmux operations for shooter.nvim
-- Send shots, mark executed, save history

local utils = require('shooter.utils')
local sound = require('shooter.sound')

local M = {}

-- Helper: Mark shot and save to history
local function mark_and_save(bufnr, shot_info, full_message)
  local shots = require('shooter.core.shots')
  local history = require('shooter.history')

  shots.mark_shot_executed(bufnr, shot_info.header_line)

  local header_text = utils.get_buf_lines(bufnr, shot_info.header_line - 1, shot_info.header_line)[1]
  local shot_num = shots.parse_shot_header(header_text)
  local shot_content = shots.get_shot_content(bufnr, shot_info.start_line, shot_info.end_line)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  history.save_shot(shot_content, full_message, shot_num, filepath)
end

-- Helper: Find pane or create one, show error on failure
local function find_pane_or_error(detect, pane_index)
  local create = require('shooter.tmux.create')
  local pane_id, err = create.find_or_create_claude_pane(pane_index)
  if not pane_id then
    utils.echo(err or 'Failed to find or create Claude pane')
    return nil
  end
  return pane_id
end

-- Check if shot is already executed (has x in header)
local function is_shot_executed(bufnr, header_line)
  local config = require('shooter.config')
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  return header_text:match(config.get('patterns.executed_shot_header')) ~= nil
end

-- Send current shot to Claude pane using file reference (@filepath)
function M.send_current_shot(pane_index, detect, send, messages)
  pane_index = pane_index or 1

  local files = require('shooter.core.files')
  local shots = require('shooter.core.shots')
  local history = require('shooter.history')

  -- Check if we're in a shooter file
  if not files.is_shooter_file() then
    local text = utils.get_current_line()
    local pane_id = find_pane_or_error(detect, pane_index)
    if pane_id then send.send_to_pane(pane_id, text) end
    return
  end

  local bufnr = utils.current_buf()
  local cursor_line = utils.get_cursor()[1]
  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, cursor_line)

  if not shot_start then
    utils.echo('No shot found at cursor position')
    return
  end

  -- Check if shot is already executed and ask for confirmation
  if is_shot_executed(bufnr, header_line) then
    local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
    local shot_num = shots.parse_shot_header(header_text)
    local choice = vim.fn.confirm(
      string.format('Shot %s was already sent. Resend?', shot_num),
      '&Yes\n&No',
      2
    )
    if choice ~= 1 then
      utils.echo('Resend cancelled')
      return
    end
  end

  local shot_info = { start_line = shot_start, end_line = shot_end, header_line = header_line }
  local full_message = messages.build_shot_message(bufnr, shot_info)

  -- Get shot number for file naming
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Save message to sendable file
  local sendable_path, save_err = history.save_sendable(full_message, shot_num, filepath)
  if not sendable_path then
    utils.echo('Failed to save sendable file: ' .. (save_err or 'unknown error'))
    return
  end

  local pane_id = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  -- Send file reference instead of pasting content
  local success, err = send.send_file_reference(pane_id, sendable_path)

  if success then
    mark_and_save(bufnr, shot_info, full_message)
    local file_title = files.get_file_title(bufnr)
    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent shot %s to claude%s (%s)', shot_num, pane_msg, file_title))
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send all open shots to Claude pane using file reference
function M.send_all_shots(pane_index, detect, send, messages)
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

  local full_message = messages.build_multishot_message(bufnr, open_shots)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Build shot numbers string for filename
  local shot_nums = {}
  for _, shot_info in ipairs(open_shots) do
    local header_text = utils.get_buf_lines(bufnr, shot_info.header_line - 1, shot_info.header_line)[1]
    local shot_num = shots.parse_shot_header(header_text)
    table.insert(shot_nums, shot_num)
  end
  local shots_str = table.concat(shot_nums, '-')

  -- Save message to sendable file
  local sendable_path, save_err = history.save_sendable(full_message, shots_str, filepath)
  if not sendable_path then
    utils.echo('Failed to save sendable file: ' .. (save_err or 'unknown error'))
    return
  end

  local pane_id = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  -- Send file reference instead of pasting content
  local success, err = send.send_file_reference(pane_id, sendable_path)

  if success then
    for _, shot_info in ipairs(open_shots) do
      mark_and_save(bufnr, shot_info, full_message)
    end
    local file_title = files.get_file_title(bufnr)
    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent %d shots to claude%s (%s)', #open_shots, pane_msg, file_title))
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send visual selection to Claude pane
function M.send_visual_selection(pane_index, start_line, end_line, detect, send)
  pane_index = pane_index or 1

  local bufnr = utils.current_buf()
  local lines = utils.get_buf_lines(bufnr, start_line - 1, end_line)
  local text = table.concat(lines, '\n')

  if not text or text == '' or text:match('^%s*$') then
    utils.echo('No text selected')
    return
  end

  local pane_id = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  local success, err, text_length = send.send_to_pane(pane_id, text)

  if success then
    local pane_msg = pane_index == 1 and '' or string.format(' #%d', pane_index)
    utils.echo(string.format('Sent selection to claude%s (%d chars)', pane_msg, text_length))
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send specific shots to Claude pane using file reference (used by telescope multi-select)
function M.send_specific_shots(pane_index, shot_infos, bufnr, detect, send, messages)
  pane_index = pane_index or 1
  bufnr = bufnr or utils.current_buf()

  local files = require('shooter.core.files')
  local shots = require('shooter.core.shots')
  local history = require('shooter.history')

  if #shot_infos == 0 then
    utils.echo('No shots to send')
    return
  end

  local full_message = messages.build_multishot_message(bufnr, shot_infos)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Build shot numbers string for filename
  local shot_nums = {}
  for _, shot_info in ipairs(shot_infos) do
    local header_text = utils.get_buf_lines(bufnr, shot_info.header_line - 1, shot_info.header_line)[1]
    local shot_num = shots.parse_shot_header(header_text)
    table.insert(shot_nums, shot_num)
  end
  local shots_str = table.concat(shot_nums, '-')

  -- Save message to sendable file
  local sendable_path, save_err = history.save_sendable(full_message, shots_str, filepath)
  if not sendable_path then
    utils.echo('Failed to save sendable file: ' .. (save_err or 'unknown error'))
    return
  end

  local pane_id = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  -- Send file reference instead of pasting content
  local success, err = send.send_file_reference(pane_id, sendable_path)

  if success then
    for _, shot_info in ipairs(shot_infos) do
      mark_and_save(bufnr, shot_info, full_message)
    end
    local file_title = files.get_file_title(bufnr)
    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent %d shots to claude%s (%s)', #shot_infos, pane_msg, file_title))
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

return M

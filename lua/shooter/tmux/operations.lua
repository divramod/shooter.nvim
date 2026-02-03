-- High-level tmux operations: send shots to AI panes

local utils = require('shooter.utils')
local sound = require('shooter.sound')

local M = {}

local function get_shots() return require('shooter.core.shots') end
local function get_files() return require('shooter.core.files') end
local function get_providers() return require('shooter.providers') end
local function get_renumber_helper() return require('shooter.tmux.renumber_helper') end

local function mark_shot(bufnr, shot_info)
  get_shots().mark_shot_executed(bufnr, shot_info.header_line)
end

local function find_pane_or_error(_, pane_index)
  local create = require('shooter.tmux.create')
  local pane_id, err = create.find_or_create_ai_pane(pane_index)
  if not pane_id then
    utils.echo(err or 'Failed to find or create AI pane')
    return nil, nil, nil
  end
  local provider_name, provider = get_providers().detect_provider_for_pane(pane_id)
  return pane_id, provider_name or 'AI', provider
end

local function send_file_ref(provider, send, pane_id, filepath)
  if provider and provider.send_file_reference then return provider.send_file_reference(pane_id, filepath) end
  return send.send_file_reference(pane_id, filepath)
end

local function save_temp_sendable(full_message, shot_num)
  local temp_dir = utils.expand_path('~/.config/shooter.nvim/tmp')
  utils.ensure_dir(temp_dir)
  local timestamp = os.date('%Y%m%d_%H%M%S')
  local temp_path = string.format('%s/shot-%s-%s.md', temp_dir, shot_num, timestamp)
  local success = utils.write_file(temp_path, full_message)
  return success and temp_path or nil
end

local function is_shot_executed(bufnr, header_line)
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  return header_text:match(require('shooter.config').get('patterns.executed_shot_header')) ~= nil
end

local function build_shots_str(bufnr, shot_infos)
  local shots = get_shots()
  local nums = {}
  for _, info in ipairs(shot_infos) do
    local header = utils.get_buf_lines(bufnr, info.header_line - 1, info.header_line)[1]
    table.insert(nums, shots.parse_shot_header(header))
  end
  return table.concat(nums, '-')
end

function M.send_current_shot(pane_index, detect, send, messages)
  pane_index = pane_index or 1
  local files, shots = get_files(), get_shots()

  if not files.is_shooter_file() then
    local pane_id = find_pane_or_error(detect, pane_index)
    if pane_id then send.send_to_pane(pane_id, utils.get_current_line()) end
    return
  end

  local bufnr = utils.current_buf()
  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, utils.get_cursor()[1])
  if not shot_start then utils.echo('No shot found at cursor position'); return end

  -- Confirm resend for already-executed shots
  local already_executed = is_shot_executed(bufnr, header_line)
  if already_executed then
    local header = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
    if vim.fn.confirm('Shot ' .. shots.parse_shot_header(header) .. ' already sent. Resend?', '&Yes\n&No', 2) ~= 1 then
      utils.echo('Resend cancelled'); return
    end
  end

  -- Mark as executed FIRST (so renumbering treats it as a done shot)
  if not already_executed then
    local shot_info = { start_line = shot_start, end_line = shot_end, header_line = header_line }
    mark_shot(bufnr, shot_info)
  end

  -- Renumber shots and find the same shot by content hash
  local new_start, new_end, new_header = get_renumber_helper().renumber_and_find_shot(bufnr, shot_start, shot_end)
  if not new_start then
    utils.echo('Failed to locate shot after renumbering')
    return
  end
  shot_start, shot_end, header_line = new_start, new_end, new_header

  local shot_info = { start_line = shot_start, end_line = shot_end, header_line = header_line }
  local full_message = messages.build_shot_message(bufnr, shot_info)
  local shot_num = build_shots_str(bufnr, { shot_info })

  -- Write to temp file for sending
  local temp_path = save_temp_sendable(full_message, shot_num)
  if not temp_path then utils.echo('Failed to save temp file'); return end

  local pane_id, provider_name, provider = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  local success, err = send_file_ref(provider, send, pane_id, temp_path)
  if success then
    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent shot %s to %s%s (%s)', shot_num, provider_name, pane_msg, files.get_file_title(bufnr)))
    vim.api.nvim_win_set_cursor(0, { header_line, 0 })  -- Stay on sent shot
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send all open shots to AI pane
function M.send_all_shots(pane_index, detect, send, messages)
  pane_index = pane_index or 1
  local files, shots = get_files(), get_shots()

  if not files.is_shooter_file() then utils.echo('Multishot only works in shooter files'); return end

  local bufnr = utils.current_buf()
  local open_shots = shots.find_open_shots(bufnr)
  if #open_shots == 0 then utils.echo('No open shots found'); return end

  -- Mark all as executed FIRST, then renumber (so they get final done-shot numbers)
  for _, shot_info in ipairs(open_shots) do mark_shot(bufnr, shot_info) end
  require('shooter.core.renumber').renumber_shots(bufnr)

  -- Re-fetch executed shots (they moved after renumber) - get only the ones just marked
  local executed_shots = get_renumber_helper().find_executed_shots(bufnr)

  local full_message = messages.build_multishot_message(bufnr, executed_shots)
  local shots_str = build_shots_str(bufnr, executed_shots)
  local temp_path = save_temp_sendable(full_message, shots_str)
  if not temp_path then utils.echo('Failed to save temp file'); return end

  local pane_id, provider_name, provider = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  local success, err = send_file_ref(provider, send, pane_id, temp_path)
  if success then
    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent %d shots to %s%s (%s)', #executed_shots, provider_name, pane_msg, files.get_file_title(bufnr)))
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send visual selection to AI pane
function M.send_visual_selection(pane_index, start_line, end_line, detect, send)
  pane_index = pane_index or 1
  local text = table.concat(utils.get_buf_lines(utils.current_buf(), start_line - 1, end_line), '\n')
  if not text or text:match('^%s*$') then utils.echo('No text selected'); return end

  local pane_id, provider_name = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  local success, err, text_length = send.send_to_pane(pane_id, text)
  if success then
    local pane_msg = pane_index == 1 and '' or string.format(' #%d', pane_index)
    utils.echo(string.format('Sent selection to %s%s (%d chars)', provider_name, pane_msg, text_length))
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

-- Send specific shots to AI pane (used by telescope multi-select)
-- Note: No auto-renumber here since shot_infos have specific line numbers
-- that would become invalid after renumber. User should renumber before opening picker.
function M.send_specific_shots(pane_index, shot_infos, bufnr, detect, send, messages)
  pane_index = pane_index or 1
  bufnr = bufnr or utils.current_buf()
  local files = get_files()

  if #shot_infos == 0 then utils.echo('No shots to send'); return end

  local full_message = messages.build_multishot_message(bufnr, shot_infos)
  local shots_str = build_shots_str(bufnr, shot_infos)
  local temp_path = save_temp_sendable(full_message, shots_str)
  if not temp_path then utils.echo('Failed to save temp file'); return end

  local pane_id, provider_name, provider = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  local success, err = send_file_ref(provider, send, pane_id, temp_path)
  if success then
    for _, shot_info in ipairs(shot_infos) do mark_shot(bufnr, shot_info) end
    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent %d shots to %s%s (%s)', #shot_infos, provider_name, pane_msg, files.get_file_title(bufnr)))
    sound.play()
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

return M

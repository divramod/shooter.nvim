-- High-level tmux operations: send shots to AI panes
local utils = require('shooter.utils')
local sound = require('shooter.sound')
local M = {}

local function get_shots() return require('shooter.core.shots') end
local function get_files() return require('shooter.core.files') end
local function get_providers() return require('shooter.providers') end
local function get_renumber_helper() return require('shooter.tmux.renumber_helper') end
local function mark_shot(bufnr, shot_info) get_shots().mark_shot_executed(bufnr, shot_info.header_line) end

local function get_nvim_pane_id()
  return vim.trim(vim.fn.system({"tmux", "display-message", "-p", "#{pane_id}"}))
end

local function find_pane_or_error(_, pane_index)
  local create = require('shooter.tmux.create')
  local pane_id, err = create.find_or_create_ai_pane(pane_index)
  if not pane_id then
    utils.echo(err or 'Failed to find or create AI pane')
    return nil, nil, nil
  end
  -- Safety: never send to nvim's own pane
  local nvim_pane = get_nvim_pane_id()
  if pane_id == nvim_pane then
    utils.echo('Error: AI pane ID matches nvim pane, aborting')
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
  local ts = os.date('%Y%m%d_%H%M%S')
  local temp_path = string.format('%s/shot-%s-%s.md', temp_dir, shot_num, ts)
  return utils.write_file(temp_path, full_message) and temp_path or nil
end

local function add_temp_ref_to_header(bufnr, header_line, temp_filename)
  local line = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  line = line:gsub('%s*@shot%-[%d_%-]+', '') .. ' @' .. temp_filename
  utils.set_buf_lines(bufnr, header_line - 1, header_line, { line })
  if vim.api.nvim_buf_get_name(bufnr) ~= '' then vim.cmd('write') end
end

local function is_shot_executed(bufnr, header_line)
  local h = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  return h:match(require('shooter.config').get('patterns.executed_shot_header')) ~= nil
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

  -- Lock buffer during pane creation to prevent terminal escape sequences
  -- (e.g., iTerm2 OSC 1337 clipboard responses) from being inserted during
  -- vim.wait event processing when the tmux split triggers a resize
  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = false

  -- Find/create pane FIRST (potentially long: prompt + split + AI startup wait)
  -- Must happen before buffer modifications to avoid state loss during waits
  local pane_id, provider_name, provider = find_pane_or_error(detect, pane_index)

  -- Recover clean state BEFORE unlocking buffer:
  -- iTerm2 OSC 1337 escape sequences arrive as typeahead during vim.wait().
  -- With buffer locked they can't insert text, but unlocking too early lets
  -- the remaining typeahead characters through. So: force normal mode,
  -- wait for in-flight sequences to arrive, drain them, THEN unlock.
  vim.cmd('stopinsert')
  vim.wait(150, function() return false end, 30)  -- let in-flight escapes arrive
  while vim.fn.getchar(0) ~= 0 do end             -- drain typeahead
  vim.cmd('stopinsert')                             -- ensure normal mode after drain
  vim.bo[bufnr].modifiable = was_modifiable

  if not pane_id then return end

  -- All buffer modifications happen quickly in sequence after pane is ready
  -- Mark as executed (so renumbering treats it as a done shot)
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

  local success, err = send_file_ref(provider, send, pane_id, temp_path)
  if success then
    -- Add temp file reference to header for response lookup
    local temp_filename = temp_path:match('[^/]+$'):gsub('%.md$', '')
    add_temp_ref_to_header(bufnr, header_line, temp_filename)

    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent shot %s to %s%s (%s)', shot_num, provider_name, pane_msg, files.get_file_title(bufnr)))
    vim.cmd('stopinsert')
    vim.api.nvim_win_set_cursor(0, { header_line, 0 })  -- Stay on sent shot
    sound.play()
    -- Late-arriving escape sequence safety net: schedule a deferred cleanup
    vim.schedule(function()
      while vim.fn.getchar(0) ~= 0 do end
      vim.cmd('stopinsert')
    end)
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
  -- Mark all as executed FIRST, then renumber
  for _, shot_info in ipairs(open_shots) do mark_shot(bufnr, shot_info) end
  require('shooter.core.renumber').renumber_shots(bufnr)
  local executed_shots = get_renumber_helper().find_executed_shots(bufnr)
  local full_message = messages.build_multishot_message(bufnr, executed_shots)
  local shots_str = build_shots_str(bufnr, executed_shots)
  local temp_path = save_temp_sendable(full_message, shots_str)
  if not temp_path then utils.echo('Failed to save temp file'); return end
  local pane_id, provider_name, provider = find_pane_or_error(detect, pane_index)
  if not pane_id then return end

  local success, err = send_file_ref(provider, send, pane_id, temp_path)
  if success then
    -- Add temp file reference to each sent shot's header
    local temp_filename = temp_path:match('[^/]+$'):gsub('%.md$', '')
    for _, ex in ipairs(executed_shots) do
      add_temp_ref_to_header(bufnr, ex.header_line, temp_filename)
    end

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
function M.send_specific_shots(pane_index, shot_infos, bufnr, detect, send, messages)
  pane_index = pane_index or 1
  bufnr = bufnr or utils.current_buf()
  local files = get_files()

  if #shot_infos == 0 then utils.echo('No shots to send'); return end

  -- Build message BEFORE marking (so headers show original shot numbers)
  local full_message = messages.build_multishot_message(bufnr, shot_infos)
  local shots_str = build_shots_str(bufnr, shot_infos)
  local temp_path = save_temp_sendable(full_message, shots_str)
  if not temp_path then utils.echo('Failed to save temp file'); return end

  -- Lock buffer during pane creation (same protection as send_current_shot)
  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = false

  local pane_id, provider_name, provider = find_pane_or_error(detect, pane_index)

  -- Drain typeahead before unlocking (iTerm2 OSC 1337 protection)
  vim.cmd('stopinsert')
  vim.wait(150, function() return false end, 30)
  while vim.fn.getchar(0) ~= 0 do end
  vim.cmd('stopinsert')
  vim.bo[bufnr].modifiable = was_modifiable

  if not pane_id then return end

  -- Capture sent shot numbers before marking (headers change after mark+renumber)
  local sent_nums = {}
  for _, shot_info in ipairs(shot_infos) do
    local header = utils.get_buf_lines(bufnr, shot_info.header_line - 1, shot_info.header_line)[1]
    local num = get_shots().parse_shot_header(header)
    if num then sent_nums[num] = true end
  end

  -- Mark all shots as executed, then renumber
  for _, shot_info in ipairs(shot_infos) do mark_shot(bufnr, shot_info) end
  require('shooter.core.renumber').renumber_shots(bufnr)

  local success, err = send_file_ref(provider, send, pane_id, temp_path)
  if success then
    -- Add temp file reference to each sent shot's header (like single send does)
    local temp_filename = temp_path:match('[^/]+$'):gsub('%.md$', '')
    local executed = get_renumber_helper().find_executed_shots(bufnr)
    for _, ex in ipairs(executed) do
      local h = utils.get_buf_lines(bufnr, ex.header_line - 1, ex.header_line)[1]
      local num = get_shots().parse_shot_header(h)
      if num and sent_nums[num] then
        add_temp_ref_to_header(bufnr, ex.header_line, temp_filename)
      end
    end

    local pane_msg = pane_index == 1 and '' or string.format(' to #%d', pane_index)
    utils.echo(string.format('Sent %d shots to %s%s (%s)', #shot_infos, provider_name, pane_msg, files.get_file_title(bufnr)))
    vim.cmd('stopinsert')
    sound.play()
    vim.schedule(function()
      while vim.fn.getchar(0) ~= 0 do end
      vim.cmd('stopinsert')
    end)
  else
    utils.echo('Failed to send: ' .. (err or 'unknown error'))
  end
end

return M

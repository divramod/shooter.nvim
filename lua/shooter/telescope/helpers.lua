-- Telescope helper functions for shooter.nvim
local M = {}

local action_state = require('telescope.actions.state')
local utils = require('shooter.utils')

-- Persistent state storage (file -> { selections = set of shot numbers, cursor_row = number })
M.persistent_state = {}

-- Clear persistent state for a file
function M.clear_selection(filepath)
  if filepath then
    M.persistent_state[filepath] = nil
  else
    M.persistent_state = {}
  end
end

-- Get target file (current file if in prompts, or last edited)
function M.get_target_file()
  local cwd = vim.fn.getcwd()
  local prompts_path = cwd .. '/plans/prompts'
  local filepath = vim.fn.expand('%:p')

  if filepath:find(prompts_path, 1, true) then
    return filepath, true
  end

  if vim.fn.isdirectory(prompts_path) ~= 1 then return nil, false end
  local handle = io.popen('find "' .. prompts_path .. '" -name "*.md" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1')
  if not handle then return nil, false end
  local last_file = handle:read('*l')
  handle:close()
  return last_file and last_file ~= '' and last_file or nil, false
end

-- Read file lines (from buffer if current, from disk otherwise)
function M.read_lines(target_file, is_current)
  if is_current then
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end
  local file = io.open(target_file, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  local lines = {}
  for line in content:gmatch('[^\n]*') do
    table.insert(lines, line)
  end
  return lines
end

-- Find open shots in file content (array of lines)
function M.find_open_shots(lines)
  local shots = {}
  local i = 1
  while i <= #lines do
    if lines[i]:match('^##%s+shot') and not lines[i]:match('^##%s+x%s+shot') then
      local start_line = i
      local end_line = #lines
      for j = start_line + 1, #lines do
        if lines[j]:match('^##%s+x?%s*shot') then
          end_line = j - 1
          break
        end
      end
      while end_line > start_line and lines[end_line]:match('^%s*$') do
        end_line = end_line - 1
      end
      table.insert(shots, {start_line = start_line, end_line = end_line, header_line = start_line})
      i = end_line + 1
    else
      i = i + 1
    end
  end
  return shots
end

-- Create shot entry for telescope picker
function M.make_shot_entry(shot, lines, target_file, is_current)
  local header = lines[shot.header_line]
  local shot_num = header:match('shot%s+(%d+)') or '?'
  local preview_lines = {}
  for idx = shot.start_line + 1, math.min(shot.start_line + 5, shot.end_line) do
    if lines[idx] and lines[idx] ~= '' then
      table.insert(preview_lines, lines[idx])
      if #preview_lines >= 3 then break end
    end
  end
  local preview = table.concat(preview_lines, ' | ')
  if #preview > 60 then preview = preview:sub(1, 60) .. '...' end
  return {
    shot_num = shot_num, header_line = shot.header_line,
    start_line = shot.start_line, end_line = shot.end_line,
    display = string.format('Shot %s: %s', shot_num, preview),
    lines = lines, target_file = target_file, is_current_file = is_current,
  }
end

-- Save current multi-selection and cursor position to persistent storage
function M.save_selection_state(prompt_bufnr, target_file)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local multi = picker:get_multi_selection()
  local selected_shots = {}
  for _, entry in ipairs(multi) do
    if entry.value and entry.value.shot_num then
      selected_shots[entry.value.shot_num] = true
    end
  end
  M.persistent_state[target_file] = {
    selections = selected_shots,
    cursor_row = picker:get_selection_row(),
  }
end

-- Restore selection and cursor position from persistent storage (with retry)
function M.restore_selection_state(prompt_bufnr, target_file, retry_count)
  retry_count = retry_count or 0
  local max_retries = 10

  local state = M.persistent_state[target_file]
  if not state then return end

  local saved = state.selections
  local saved_cursor = state.cursor_row

  local picker = action_state.get_current_picker(prompt_bufnr)
  if not picker or not picker._multi then
    if retry_count < max_retries then
      vim.defer_fn(function()
        M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
      end, 50)
    end
    return
  end

  local manager = picker.manager
  if not manager or type(manager) ~= 'table' then
    if retry_count < max_retries then
      vim.defer_fn(function()
        M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
      end, 50)
    end
    return
  end

  -- Check if entries are ready (manager has entries)
  local has_entries = false
  for _ in manager:iter() do
    has_entries = true
    break
  end
  if not has_entries and retry_count < max_retries then
    vim.defer_fn(function()
      M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
    end, 50)
    return
  end

  -- Find which rows need to be selected
  local rows_to_select = {}
  if saved and not vim.tbl_isempty(saved) then
    local row = 0
    for entry in manager:iter() do
      if entry.value and entry.value.shot_num and saved[entry.value.shot_num] then
        table.insert(rows_to_select, row)
      end
      row = row + 1
    end
  end

  -- Use telescope actions to programmatically select each row
  if #rows_to_select > 0 then
    local actions = require('telescope.actions')
    for _, target_row in ipairs(rows_to_select) do
      picker:set_selection(target_row)
      actions.toggle_selection(prompt_bufnr)
    end
  end

  -- Restore cursor to saved position
  if saved_cursor then
    picker:set_selection(saved_cursor)
  end
end

-- Get files for telescope picker (returns display paths without plans/prompts prefix)
function M.get_prompt_files()
  local cwd = vim.fn.getcwd()
  local prompts_dir = cwd .. '/plans/prompts'
  local file_list = vim.fn.globpath(prompts_dir, '**/*.md', false, true)
  local results = {}
  for _, file in ipairs(file_list) do
    local display = file:gsub('^' .. vim.pesc(prompts_dir) .. '/', '')
    table.insert(results, { display = display, path = file })
  end
  return results
end

return M

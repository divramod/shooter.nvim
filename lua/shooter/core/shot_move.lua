-- Move shot between shotfiles
-- Flow: find shot under cursor -> pick target file -> move shot -> renumber
-- Rule: exactly one empty line above each shot header

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')
local helpers = require('shooter.telescope.helpers')

local M = {}

-- Normalize blank lines: exactly one blank line before each ## shot header
local function normalize_blank_lines(lines)
  local result = {}
  local prev_blank = false
  for i, line in ipairs(lines) do
    local is_shot = line:match('^##%s+x?%s*shot')
    if is_shot then
      -- Remove consecutive blanks before shot, ensure exactly one
      while #result > 0 and result[#result]:match('^%s*$') do
        table.remove(result)
      end
      if #result > 0 then table.insert(result, '') end -- add single blank
    end
    table.insert(result, line)
  end
  return result
end

-- Get full shot text (including header)
local function get_shot_lines(bufnr, start_line, end_line)
  return vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
end

-- Insert shot into target file with proper formatting
local function insert_shot_into_file(filepath, shot_lines, new_shot_num)
  local content = utils.read_file(filepath)
  if not content then return false end

  -- Update shot number in header
  local updated_lines = {}
  for i, line in ipairs(shot_lines) do
    if i == 1 then line = line:gsub('(##%s+x?%s*shot%s+)%d+', '%1' .. new_shot_num) end
    table.insert(updated_lines, line)
  end

  -- Parse file into lines
  local lines = {}
  for line in content:gmatch('([^\n]*)') do table.insert(lines, line) end

  -- Find where to insert (after title, before first shot)
  local insert_at = #lines + 1
  for i, line in ipairs(lines) do
    if line:match('^##%s+') then insert_at = i; break end
  end

  -- Build new content
  local new_lines = {}
  for i = 1, insert_at - 1 do table.insert(new_lines, lines[i]) end
  for _, line in ipairs(updated_lines) do table.insert(new_lines, line) end
  for i = insert_at, #lines do table.insert(new_lines, lines[i]) end

  -- Normalize blank lines (exactly one before each shot)
  new_lines = normalize_blank_lines(new_lines)
  utils.write_file(filepath, table.concat(new_lines, '\n'))
  return true
end

-- Delete shot from buffer and normalize
local function delete_shot_from_buffer(bufnr, start_line, end_line, cursor_line)
  -- Delete shot lines
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, {})

  -- Normalize the entire buffer
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local normalized = normalize_blank_lines(all_lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, normalized)

  -- Restore cursor (adjust if needed)
  local new_line = math.min(cursor_line, #normalized)
  vim.api.nvim_win_set_cursor(0, { math.max(1, new_line), 0 })
end

-- Main entry point: move shot under cursor to another file
function M.move_shot()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Find current shot
  local start_line, end_line, _ = shots.find_current_shot(bufnr, cursor_line)
  if not start_line then
    utils.notify('No shot found under cursor', vim.log.levels.WARN)
    return
  end

  -- Get shot lines
  local shot_lines = get_shot_lines(bufnr, start_line, end_line)
  local source_path = vim.api.nvim_buf_get_name(bufnr)

  -- Show file picker to select target
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local files = helpers.get_prompt_files({ include_all_projects = true })
  -- Filter out current file
  local filtered = {}
  for _, f in ipairs(files) do
    if f.path ~= source_path then table.insert(filtered, f) end
  end

  if #filtered == 0 then
    utils.notify('No other shotfiles found', vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = 'Move Shot To',
    finder = finders.new_table({
      results = filtered,
      entry_maker = function(e) return { value = e, display = e.display, ordinal = e.display, path = e.path } end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not entry or not entry.value then return end

        local target_path = entry.value.path
        -- Get next shot number in target file
        local target_buf = vim.fn.bufnr(target_path)
        local new_num
        if target_buf ~= -1 then
          new_num = shots.get_next_shot_number(target_buf)
        else
          -- Load file temporarily to get shot number
          local content = utils.read_file(target_path) or ''
          local max = 0
          for num in content:gmatch('##%s+x?%s*shot%s+(%d+)') do
            local n = tonumber(num); if n and n > max then max = n end
          end
          new_num = max + 1
        end

        -- Insert into target
        if not insert_shot_into_file(target_path, shot_lines, new_num) then
          utils.notify('Failed to insert shot into target', vim.log.levels.ERROR)
          return
        end

        -- Delete from source and normalize (pass cursor to restore position)
        delete_shot_from_buffer(bufnr, start_line, end_line, cursor_line)
        vim.cmd('write')

        utils.notify(string.format('Moved to %s as shot %d', entry.value.display, new_num), vim.log.levels.INFO)
      end)
      return true
    end,
  }):find()
end

return M

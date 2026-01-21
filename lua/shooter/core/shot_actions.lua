-- Shot action functions for shooter.nvim
-- Create, delete, and manipulate shots

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Create a new shot at the end of the file
function M.create_new_shot()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local line_count = utils.buf_line_count(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Append to end of file with blank line before
  local lines_to_add = { '', shot_header, '' }
  utils.set_buf_lines(bufnr, line_count, line_count, lines_to_add)

  -- Position cursor on the blank line after header (ready to type)
  vim.api.nvim_win_set_cursor(0, { line_count + 3, 0 })
  vim.cmd('startinsert')

  utils.notify('Created shot ' .. next_num, vim.log.levels.INFO)
end

-- Create new shot and start whisper for dictation
function M.create_new_shot_with_whisper()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local line_count = utils.buf_line_count(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Append to end of file with blank line before
  local lines_to_add = { '', shot_header, '' }
  utils.set_buf_lines(bufnr, line_count, line_count, lines_to_add)

  -- Position cursor on the blank line after header
  vim.api.nvim_win_set_cursor(0, { line_count + 3, 0 })
  vim.cmd('startinsert')

  -- Start whisper after a short delay to ensure insert mode is active
  vim.defer_fn(function()
    if vim.fn.exists(':GpWhisper') == 2 then
      vim.cmd('GpWhisper')
    else
      utils.notify('GpWhisper not available', vim.log.levels.WARN)
    end
  end, 100)

  utils.notify('Created shot ' .. next_num .. ' - speak now', vim.log.levels.INFO)
end

-- Delete the last created shot (highest numbered, not executed)
function M.delete_last_shot()
  local bufnr = 0
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  -- Find the highest shot number and its line
  local max_shot = 0
  local max_shot_line = nil
  local is_executed = false

  for i, line in ipairs(lines) do
    local shot_num = line:match('^##%s+x?%s*shot%s+(%d+)')
    if shot_num then
      local num = tonumber(shot_num)
      if num and num > max_shot then
        max_shot = num
        max_shot_line = i
        is_executed = line:match('^##%s+x%s+shot') ~= nil
      end
    end
  end

  if not max_shot_line then
    utils.notify('No shots found to delete', vim.log.levels.WARN)
    return
  end

  -- Check if already being worked on
  if is_executed then
    utils.notify('Cannot delete shot ' .. max_shot .. ' - already being worked on', vim.log.levels.ERROR)
    return
  end

  -- Find the shot's end (next shot header or end of file)
  local shot_end = #lines
  for i = max_shot_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      shot_end = i - 1
      break
    end
  end

  -- Find the shot's start (include preceding blank line if exists)
  local shot_start = max_shot_line
  if max_shot_line > 1 and lines[max_shot_line - 1]:match('^%s*$') then
    shot_start = max_shot_line - 1
  end

  -- Delete the range
  utils.set_buf_lines(bufnr, shot_start - 1, shot_end, {})

  utils.notify('Deleted shot ' .. max_shot, vim.log.levels.INFO)
end

return M

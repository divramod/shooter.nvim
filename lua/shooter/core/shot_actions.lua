-- Shot action functions for shooter.nvim
-- Create, delete, and manipulate shots

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Find the insertion point for new shots (after title, before first shot)
local function find_insertion_line(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  -- Find the title line (# ...)
  local title_line = nil
  for i, line in ipairs(lines) do
    if line:match('^#%s+[^#]') then
      title_line = i
      break
    end
  end

  -- If no title, insert at line 1
  if not title_line then
    return 1
  end

  -- Find the first shot header after title
  for i = title_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      -- Insert before this shot (with blank line)
      return i
    end
  end

  -- No shots yet, insert after title with blank line
  return title_line + 1
end

-- Create a new shot at the top (below title, above other shots)
function M.create_new_shot()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line = find_insertion_line(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Insert new shot at the top (after title)
  local lines_to_add = { '', shot_header, '' }
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the blank line after header (ready to type)
  vim.api.nvim_win_set_cursor(0, { insert_line + 2, 0 })
  vim.cmd('startinsert')

  utils.echo('Created shot ' .. next_num)
end

-- Create new shot and start whisper for dictation
function M.create_new_shot_with_whisper()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line = find_insertion_line(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Insert new shot at the top (after title)
  local lines_to_add = { '', shot_header, '' }
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the blank line after header
  vim.api.nvim_win_set_cursor(0, { insert_line + 2, 0 })
  vim.cmd('startinsert')

  -- Start whisper after a short delay to ensure insert mode is active
  vim.defer_fn(function()
    if vim.fn.exists(':GpWhisper') == 2 then
      vim.cmd('GpWhisper')
    else
      utils.echo('GpWhisper not available')
    end
  end, 100)

  utils.echo('Created shot ' .. next_num .. ' - speak now')
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
    utils.echo('No shots found to delete')
    return
  end

  -- Check if already being worked on
  if is_executed then
    utils.echo('Cannot delete shot ' .. max_shot .. ' - already being worked on')
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

  utils.echo('Deleted shot ' .. max_shot)
end

return M

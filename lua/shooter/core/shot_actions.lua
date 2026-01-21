-- Shot action functions for shooter.nvim
-- Create, delete, and manipulate shots

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Find the insertion point for new shots (after title, before first shot or orphan text)
-- Returns: insert_line, needs_blank_before (whether to add blank line before header)
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
    return 1, true
  end

  -- Find the first shot header after title
  local first_shot_line = nil
  for i = title_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      first_shot_line = i
      break
    end
  end

  -- Check for orphan text between title and first shot (or end of file)
  local search_end = first_shot_line and (first_shot_line - 1) or #lines
  local orphan_start = nil

  for i = title_line + 1, search_end do
    local line = lines[i]
    -- Non-blank text = orphan text (should become part of new shot)
    if not line:match('^%s*$') then
      orphan_start = i
      break
    end
  end

  if orphan_start then
    -- Insert above orphan text so it becomes part of the new shot
    local prev_line = lines[orphan_start - 1] or ''
    local needs_blank = not prev_line:match('^%s*$')
    return orphan_start, needs_blank
  end

  if first_shot_line then
    -- Insert before first shot
    local prev_line = lines[first_shot_line - 1] or ''
    local needs_blank = not prev_line:match('^%s*$')
    return first_shot_line, needs_blank
  end

  -- No shots and no orphan text, insert after title
  local next_line = lines[title_line + 1] or ''
  local needs_blank = not next_line:match('^%s*$')
  return title_line + 1, needs_blank
end

-- Create a new shot at the top (below title, above other shots)
function M.create_new_shot()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before = find_insertion_line(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Insert new shot at the top (after title)
  -- Structure: [blank before], header, blank (cursor), blank (spacing below)
  local lines_to_add
  local cursor_offset
  if needs_blank_before then
    lines_to_add = { '', shot_header, '', '' }
    cursor_offset = 2  -- cursor on first blank after header
  else
    lines_to_add = { shot_header, '', '' }
    cursor_offset = 1  -- cursor on first blank after header
  end
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the first blank line after header (blank below for spacing)
  vim.api.nvim_win_set_cursor(0, { insert_line + cursor_offset, 0 })
  vim.cmd('startinsert')

  utils.echo('Created shot ' .. next_num)
end

-- Create new shot and start whisper for dictation
function M.create_new_shot_with_whisper()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before = find_insertion_line(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Insert new shot at the top (after title)
  -- Structure: [blank before], header, blank (cursor), blank (spacing below)
  local lines_to_add
  local cursor_offset
  if needs_blank_before then
    lines_to_add = { '', shot_header, '', '' }
    cursor_offset = 2  -- cursor on first blank after header
  else
    lines_to_add = { shot_header, '', '' }
    cursor_offset = 1  -- cursor on first blank after header
  end
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the first blank line after header (blank below for spacing)
  vim.api.nvim_win_set_cursor(0, { insert_line + cursor_offset, 0 })
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

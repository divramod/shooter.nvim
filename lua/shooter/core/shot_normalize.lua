-- Shot normalization for shooter.nvim
-- Normalize whitespace in shots when sending

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Check if a line is inside a code block (count ``` markers above)
local function is_in_code_block(lines, line_num)
  local in_block = false
  for i = 1, line_num - 1 do
    if lines[i]:match('^```') then
      in_block = not in_block
    end
  end
  return in_block
end

-- Normalize shot whitespace in buffer:
-- 1. Remove empty lines between header and content
-- 2. Ensure exactly one empty line before next shot header
function M.normalize_shot(bufnr, header_line)
  bufnr = bufnr or 0
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)
  local modified = false

  -- Find next shot header
  local next_shot_line = nil
  for i = header_line + 1, total_lines do
    if lines[i]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, i) then
      next_shot_line = i
      break
    end
  end

  -- 1. Remove empty lines between header and content
  local content_start = header_line + 1
  while content_start <= total_lines do
    local line = utils.get_buf_lines(bufnr, content_start - 1, content_start)[1]
    if line and line:match('^%s*$') then
      utils.set_buf_lines(bufnr, content_start - 1, content_start, {})
      modified = true
      total_lines = total_lines - 1
      -- Adjust next_shot_line if it exists and was affected
      if next_shot_line then next_shot_line = next_shot_line - 1 end
    else
      break
    end
  end

  -- 2. Ensure exactly one empty line before next shot header
  if next_shot_line then
    -- Re-read lines after modifications
    lines = utils.get_buf_lines(bufnr, 0, utils.buf_line_count(bufnr))

    -- Count trailing empty lines before next shot
    local empty_count = 0
    local check_line = next_shot_line - 1
    while check_line > header_line and lines[check_line]:match('^%s*$') do
      empty_count = empty_count + 1
      check_line = check_line - 1
    end

    if empty_count == 0 then
      -- Insert one empty line before next shot
      utils.set_buf_lines(bufnr, next_shot_line - 1, next_shot_line - 1, { '' })
      modified = true
    elseif empty_count > 1 then
      -- Remove extra empty lines, keep exactly one
      local first_empty = check_line + 1
      local last_empty = next_shot_line - 1
      utils.set_buf_lines(bufnr, first_empty, last_empty, {})
      modified = true
    end
  end

  return modified
end

return M

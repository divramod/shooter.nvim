-- Shared shot-insertion helper used by create + extract sub-modules.

local utils = require('shooter.utils')

local M = {}

-- Find the insertion point for new shots (after title + meta area, before first shot).
-- The meta area is any non-shot content between the title and the first shot header.
-- Returns: insert_line, needs_blank_before, has_content_below
function M.find_insertion_line(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  local title_line = nil
  for i, line in ipairs(lines) do
    if line:match('^#%s+[^#]') then
      title_line = i
      break
    end
  end

  if not title_line then return 1, true, false end

  local first_shot_line = nil
  for i = title_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      first_shot_line = i
      break
    end
  end

  if first_shot_line then
    local prev_line = lines[first_shot_line - 1] or ''
    return first_shot_line, not prev_line:match('^%s*$'), true
  end

  -- No shots — insert after last non-blank line in the meta area.
  local last_content_line = title_line
  for i = title_line + 1, #lines do
    if not lines[i]:match('^%s*$') then
      last_content_line = i
    end
  end

  return last_content_line + 1, true, false
end

return M

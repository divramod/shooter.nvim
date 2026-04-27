-- Delete the highest-numbered open shot.

local utils = require('shooter.utils')

local M = {}

-- Delete the last created shot (highest numbered, not executed).
function M.delete_last_shot()
  local bufnr = 0
  local lines = utils.get_buf_lines(bufnr, 0, -1)

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

  if is_executed then
    utils.echo('Cannot delete shot ' .. max_shot .. ' - already being worked on')
    return
  end

  -- Find the shot's end (next shot header or end of file).
  local shot_end = #lines
  for i = max_shot_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      shot_end = i - 1
      break
    end
  end

  -- Find the shot's start (include preceding blank line if exists).
  local shot_start = max_shot_line
  if max_shot_line > 1 and lines[max_shot_line - 1]:match('^%s*$') then
    shot_start = max_shot_line - 1
  end

  utils.set_buf_lines(bufnr, shot_start - 1, shot_end, {})

  -- Ensure blank line before first shot header (after title/meta area).
  local new_lines = utils.get_buf_lines(bufnr, 0, -1)
  for i, line in ipairs(new_lines) do
    if line:match('^##%s+x?%s*shot') then
      if i > 1 and not new_lines[i - 1]:match('^%s*$') then
        utils.set_buf_lines(bufnr, i - 1, i - 1, { '' })
      end
      break
    end
  end

  utils.echo('Deleted shot ' .. max_shot)
end

return M

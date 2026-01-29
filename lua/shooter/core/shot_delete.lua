-- Delete shot under cursor
-- Removes shot from shotfile (no external history files to clean up)

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')
local config = require('shooter.config')

local M = {}

-- Parse shot header for number and status
local function parse_shot_header_full(line)
  local shot_num = line:match('shot%s+(%d+)')
  local is_done = line:match(config.get('patterns.executed_shot_header')) ~= nil
  return {
    shot_num = shot_num,
    is_done = is_done,
  }
end

-- Delete the shot under cursor
function M.delete_shot_under_cursor()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local source_filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Find the current shot
  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, cursor_line)
  if not shot_start then
    utils.echo('Not in a shot')
    return
  end

  -- Get header line and parse it
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local info = parse_shot_header_full(header_text)

  -- Confirm deletion
  local shot_desc = info.is_done and ('done shot ' .. (info.shot_num or '?')) or ('open shot ' .. (info.shot_num or '?'))
  local confirm = vim.fn.confirm('Delete ' .. shot_desc .. '?', '&Yes\n&No', 2)
  if confirm ~= 1 then
    utils.echo('Cancelled')
    return
  end

  -- Delete the shot lines from buffer
  -- Include one blank line above if present (for proper formatting)
  local delete_start = shot_start
  if delete_start > 1 then
    local prev_line = utils.get_buf_lines(bufnr, delete_start - 2, delete_start - 1)[1]
    if prev_line and prev_line:match('^%s*$') then
      delete_start = delete_start - 1
    end
  end

  -- Delete lines (0-indexed for nvim_buf_set_lines)
  utils.set_buf_lines(bufnr, delete_start - 1, shot_end, {})

  -- Save the file
  if source_filepath ~= '' then
    vim.cmd('write')
  end

  utils.echo('Deleted ' .. shot_desc)
end

return M

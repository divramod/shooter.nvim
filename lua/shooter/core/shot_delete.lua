-- Delete shot under cursor
-- For done shots: also deletes corresponding history file
-- For open shots: just removes from shotfile

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')
local history = require('shooter.history')
local config = require('shooter.config')

local M = {}

-- Convert header timestamp (YYYY-MM-DD HH:MM:SS) to file timestamp (YYYYMMDD_HHMMSS)
local function header_ts_to_file_ts(header_timestamp)
  if not header_timestamp then return nil end
  -- "2026-01-29 10:09:19" -> "20260129_100919"
  local y, m, d, h, min, s = header_timestamp:match('(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)')
  if y then
    return string.format('%s%s%s_%s%s%s', y, m, d, h, min, s)
  end
  return nil
end

-- Parse shot header for number and timestamp
local function parse_shot_header_full(line)
  local shot_num = line:match('shot%s+(%d+)')
  local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)%s*$')
  local is_done = line:match(config.get('patterns.executed_shot_header')) ~= nil
  return {
    shot_num = shot_num,
    timestamp = timestamp,
    is_done = is_done,
  }
end

-- Find and delete history file for a done shot
local function delete_history_file(source_filepath, shot_num, header_timestamp)
  local user, repo = history.get_git_remote_info(source_filepath)
  if not user or not repo then
    local dir = source_filepath and utils.get_dirname(source_filepath) or utils.cwd()
    user = 'local'
    repo = utils.get_basename(history.get_git_root_for_path(source_filepath) or dir)
  end

  local project = history.detect_project_from_path(source_filepath)
  local source_filename = utils.get_filename(source_filepath)
  local file_ts = header_ts_to_file_ts(header_timestamp)

  if not file_ts then
    return false, 'Could not parse timestamp from shot header'
  end

  local history_path = history.build_history_path(user, repo, source_filename, shot_num, file_ts, project)

  if utils.file_exists(history_path) then
    local ok = os.remove(history_path)
    if ok then
      return true, history_path
    else
      return false, 'Failed to delete: ' .. history_path
    end
  else
    -- History file doesn't exist, that's okay
    return true, nil
  end
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

  -- If done shot, delete history file first
  local history_deleted = nil
  if info.is_done and info.shot_num and info.timestamp then
    local ok, result = delete_history_file(source_filepath, info.shot_num, info.timestamp)
    if ok and result then
      history_deleted = result
    end
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

  -- Report what was done
  if history_deleted then
    utils.echo('Deleted ' .. shot_desc .. ' and history file')
  else
    utils.echo('Deleted ' .. shot_desc)
  end
end

return M

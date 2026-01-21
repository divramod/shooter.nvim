-- Shot history module for shooter.nvim
-- Saves every shot to ~/.config/shooter.nvim/history/<user>/<repo>/<filename>/shot-<number>-<timestamp>.md

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Get git remote info (returns user, repo or nil)
function M.get_git_remote_info()
  local result = utils.system('git remote get-url origin 2>/dev/null')
  if not result or result == '' then
    return nil, nil
  end

  result = utils.trim(result)

  -- Parse git@github.com:user/repo.git
  local user, repo = result:match('git@[^:]+:([^/]+)/([^/%.]+)')
  if user and repo then
    return user, repo
  end

  -- Parse https://github.com/user/repo.git
  user, repo = result:match('https?://[^/]+/([^/]+)/([^/%.]+)')
  if user and repo then
    return user, repo
  end

  return nil, nil
end

-- Get history base directory
function M.get_history_base_dir()
  return utils.expand_path('~/.config/shooter.nvim/history')
end

-- Format shot number with leading zeros (e.g., 7 -> "0007", "170-169" -> "0170-0169")
function M.format_shot_number(shot_num)
  local str = tostring(shot_num)
  -- Handle multi-shot format (e.g., "170-169")
  if str:match('%-') then
    local parts = {}
    for num in str:gmatch('([^-]+)') do
      local n = tonumber(num) or 0
      table.insert(parts, string.format('%04d', n))
    end
    return table.concat(parts, '-')
  end
  local num = tonumber(str) or 0
  return string.format('%04d', num)
end

-- Generate timestamp string for filenames (yyyymmdd_hhmmss)
function M.get_file_timestamp()
  return os.date('%Y%m%d_%H%M%S')
end

-- Build history file path for a shot
-- Returns: ~/.config/shooter.nvim/history/<user>/<repo>/<filename>/shot-<number>-<timestamp>.md
function M.build_history_path(user, repo, source_filename, shot_num, timestamp)
  local base_dir = M.get_history_base_dir()
  local formatted_num = M.format_shot_number(shot_num)
  timestamp = timestamp or M.get_file_timestamp()

  -- Remove extension from source filename
  local filename_base = utils.get_basename(source_filename)

  local dir_path = string.format('%s/%s/%s/%s', base_dir, user, repo, filename_base)
  local file_path = string.format('%s/shot-%s-%s.md', dir_path, formatted_num, timestamp)

  return file_path, dir_path
end

-- Save shot to history
-- @param shot_content: The actual shot content (what user wrote)
-- @param full_message: The full message sent to Claude (with context)
-- @param shot_num: The shot number
-- @param source_filepath: The file the shot came from
-- @return success, error_message
function M.save_shot(shot_content, full_message, shot_num, source_filepath)
  local user, repo = M.get_git_remote_info()

  if not user or not repo then
    -- Fallback: use current directory name
    local cwd = utils.cwd()
    user = 'local'
    repo = utils.get_basename(cwd)
  end

  local source_filename = utils.get_filename(source_filepath)
  local file_path, dir_path = M.build_history_path(user, repo, source_filename, shot_num)

  -- Ensure directory exists
  utils.ensure_dir(dir_path)

  -- Build history file content
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local history_content = string.format([[---
shot: %s
source: %s
repo: %s/%s
timestamp: %s
---

# Shot Content

%s

# Full Message Sent

%s
]], shot_num, source_filepath, user, repo, timestamp, shot_content, full_message)

  -- Write the file
  local success, err = utils.write_file(file_path, history_content)
  if not success then
    return false, err
  end

  return true, nil
end

-- Save shot message as a sendable file (just the message, no metadata)
-- Returns: filepath on success, nil and error on failure
function M.save_sendable(full_message, shot_num, source_filepath)
  local user, repo = M.get_git_remote_info()

  if not user or not repo then
    local cwd = utils.cwd()
    user = 'local'
    repo = utils.get_basename(cwd)
  end

  local source_filename = utils.get_filename(source_filepath)
  local file_path, dir_path = M.build_history_path(user, repo, source_filename, shot_num)

  -- Ensure directory exists
  utils.ensure_dir(dir_path)

  -- Write just the message content (what Claude will read)
  local success, err = utils.write_file(file_path, full_message)
  if not success then
    return nil, err
  end

  return file_path, nil
end

-- Get history for a specific shot
function M.get_shot_history(user, repo, filename, shot_num)
  local file_path = M.build_history_path(user, repo, filename, shot_num)

  if not utils.file_exists(file_path) then
    return nil, 'History file not found'
  end

  return utils.read_file(file_path)
end

-- List all shots in history for current repo
function M.list_history()
  local user, repo = M.get_git_remote_info()
  if not user or not repo then
    return {}
  end

  local base_dir = M.get_history_base_dir()
  local repo_dir = string.format('%s/%s/%s', base_dir, user, repo)

  if not utils.dir_exists(repo_dir) then
    return {}
  end

  local cmd = string.format('find "%s" -name "shot-*.md" -type f 2>/dev/null', repo_dir)
  local result = utils.system(cmd)

  if not result or result == '' then
    return {}
  end

  local files = {}
  for file in result:gmatch('[^\n]+') do
    table.insert(files, file)
  end

  return files
end

-- Re-export migration function from submodule
function M.migrate_history_files()
  local migrate = require('shooter.history.migrate')
  return migrate.migrate_history_files()
end

return M

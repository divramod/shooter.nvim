-- Shot history module for shooter.nvim
-- Saves every shot to ~/.config/shooter.nvim/history/<user>/<repo>/<filename>/shot-<number>-<timestamp>.md

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Get git root for a specific filepath (or cwd if nil)
function M.get_git_root_for_path(filepath)
  local cmd
  if filepath then
    local dir = utils.get_dirname(filepath)
    cmd = string.format('git -C "%s" rev-parse --show-toplevel 2>/dev/null', dir)
  else
    cmd = 'git rev-parse --show-toplevel 2>/dev/null'
  end
  local result = utils.system(cmd)
  if not result or result == '' then
    return nil
  end
  return utils.trim(result)
end

-- Get git remote info (returns user, repo or nil)
-- filepath: optional path to determine which git repo to query
function M.get_git_remote_info(filepath)
  local cmd
  if filepath then
    local dir = utils.get_dirname(filepath)
    cmd = string.format('git -C "%s" remote get-url origin 2>/dev/null', dir)
  else
    cmd = 'git remote get-url origin 2>/dev/null'
  end
  local result = utils.system(cmd)
  if not result or result == '' then
    return nil, nil
  end

  result = utils.trim(result)

  -- Parse git@github.com:user/repo.git (handles repo names with dots like shooter.nvim)
  local user, repo = result:match('git@[^:]+:([^/]+)/(.+)%.git$')
  if user and repo then
    return user, repo
  end

  -- Parse https://github.com/user/repo.git
  user, repo = result:match('https?://[^/]+/([^/]+)/(.+)%.git$')
  if user and repo then
    return user, repo
  end

  -- Fallback: no .git suffix (some remotes don't have it)
  user, repo = result:match('git@[^:]+:([^/]+)/(.+)$')
  if user and repo then
    return user, repo
  end

  user, repo = result:match('https?://[^/]+/([^/]+)/(.+)$')
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

-- Detect project from a source file path
-- Returns project name or '_root' if not in a project
function M.detect_project_from_path(filepath)
  if not filepath then return '_root' end

  -- Use filepath-aware git root detection
  local git_root = M.get_git_root_for_path(filepath)
  if not git_root then return '_root' end

  -- Check if path contains /projects/<name>/
  local pattern = vim.pesc(git_root) .. '/projects/([^/]+)/'
  local project = filepath:match(pattern)
  return project or '_root'
end

-- Build history file path for a shot
-- Returns: ~/.config/shooter.nvim/history/<user>/<repo>/<project>/<filename>/shot-<number>-<timestamp>.md
function M.build_history_path(user, repo, source_filename, shot_num, timestamp, project)
  local base_dir = M.get_history_base_dir()
  local formatted_num = M.format_shot_number(shot_num)
  timestamp = timestamp or M.get_file_timestamp()
  project = project or '_root'

  -- Remove extension from source filename
  local filename_base = utils.get_basename(source_filename)

  local dir_path = string.format('%s/%s/%s/%s/%s', base_dir, user, repo, project, filename_base)
  local file_path = string.format('%s/shot-%s-%s.md', dir_path, formatted_num, timestamp)

  return file_path, dir_path
end

-- Save shot to history
-- @param shot_content: The actual shot content (what user wrote)
-- @param full_message: The full message sent to Claude (with context)
-- @param shot_num: The shot number
-- @param source_filepath: The file the shot came from
-- @param timestamp: Optional timestamp to use (for consistency with save_sendable)
-- @return success, error_message
function M.save_shot(shot_content, full_message, shot_num, source_filepath, timestamp)
  -- Use source_filepath to get git remote info from the correct repo
  local user, repo = M.get_git_remote_info(source_filepath)

  if not user or not repo then
    -- Fallback: use directory name of the source file
    local dir = source_filepath and utils.get_dirname(source_filepath) or utils.cwd()
    user = 'local'
    repo = utils.get_basename(M.get_git_root_for_path(source_filepath) or dir)
  end

  local project = M.detect_project_from_path(source_filepath)
  local source_filename = utils.get_filename(source_filepath)
  timestamp = timestamp or M.get_file_timestamp()
  local file_path, dir_path = M.build_history_path(user, repo, source_filename, shot_num, timestamp, project)

  -- Ensure directory exists
  utils.ensure_dir(dir_path)

  -- Build history file content (human-readable timestamp for metadata)
  local readable_timestamp = os.date('%Y-%m-%d %H:%M:%S')
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
]], shot_num, source_filepath, user, repo, readable_timestamp, shot_content, full_message)

  -- Write the file
  local success, err = utils.write_file(file_path, history_content)
  if not success then
    return false, err
  end

  return true, nil
end

-- Save shot message as a sendable file (just the message, no metadata)
-- Returns: filepath, timestamp on success (timestamp for use with save_shot)
-- Returns: nil, error on failure
function M.save_sendable(full_message, shot_num, source_filepath)
  -- Use source_filepath to get git remote info from the correct repo
  local user, repo = M.get_git_remote_info(source_filepath)

  if not user or not repo then
    -- Fallback: use directory name of the source file
    local dir = source_filepath and utils.get_dirname(source_filepath) or utils.cwd()
    user = 'local'
    repo = utils.get_basename(M.get_git_root_for_path(source_filepath) or dir)
  end

  local project = M.detect_project_from_path(source_filepath)
  local source_filename = utils.get_filename(source_filepath)
  local timestamp = M.get_file_timestamp()
  local file_path, dir_path = M.build_history_path(user, repo, source_filename, shot_num, timestamp, project)

  -- Ensure directory exists
  utils.ensure_dir(dir_path)

  -- Write just the message content (what Claude will read)
  local success, err = utils.write_file(file_path, full_message)
  if not success then
    return nil, err
  end

  return file_path, timestamp
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

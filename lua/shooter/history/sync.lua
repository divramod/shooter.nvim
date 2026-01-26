-- History sync module for shooter.nvim
-- Handles synchronization between prompt files and history folders

local utils = require('shooter.utils')

local M = {}

-- Get history module (lazy load to avoid circular deps)
local function get_history()
  return require('shooter.history')
end

-- Find history folder for a source file path
-- Returns: folder_path or nil
function M.find_history_folder(source_filepath)
  if not source_filepath then return nil end

  local history = get_history()
  local user, repo = history.get_git_remote_info()
  if not user then
    user, repo = 'local', utils.get_basename(utils.cwd())
  end

  local project = history.detect_project_from_path(source_filepath)
  local basename = utils.get_basename(source_filepath)
  local base_dir = history.get_history_base_dir()

  local folder = string.format('%s/%s/%s/%s/%s', base_dir, user, repo, project, basename)
  if utils.dir_exists(folder) then
    return folder
  end
  return nil
end

-- Build history folder path (even if it doesn't exist yet)
function M.build_history_folder_path(source_filepath)
  if not source_filepath then return nil end

  local history = get_history()
  local user, repo = history.get_git_remote_info()
  if not user then
    user, repo = 'local', utils.get_basename(utils.cwd())
  end

  local project = history.detect_project_from_path(source_filepath)
  local basename = utils.get_basename(source_filepath)
  local base_dir = history.get_history_base_dir()

  return string.format('%s/%s/%s/%s/%s', base_dir, user, repo, project, basename)
end

-- Get all history shot files in a folder
function M.get_history_files(folder_path)
  if not folder_path or not utils.dir_exists(folder_path) then
    return {}
  end
  return vim.fn.globpath(folder_path, 'shot-*.md', false, true)
end

-- Parse YAML frontmatter from a history file
-- Returns table with fields or nil
function M.parse_frontmatter(filepath)
  local content = utils.read_file(filepath)
  if not content then return nil end

  -- Check for frontmatter delimiters
  if not content:match('^%-%-%-\n') then return nil end

  local fm_end = content:find('\n%-%-%-\n', 4)
  if not fm_end then return nil end

  local fm_text = content:sub(5, fm_end - 1)
  local result = {}

  for line in fm_text:gmatch('[^\n]+') do
    local key, value = line:match('^([%w_]+):%s*(.+)$')
    if key and value then
      result[key] = value
    end
  end

  return result
end

-- Update a field in YAML frontmatter
-- Returns true on success
function M.update_frontmatter_field(filepath, field, new_value)
  local content = utils.read_file(filepath)
  if not content then return false end

  -- Pattern to find and replace field value
  local pattern = '(' .. field .. ':%s*)([^\n]+)'
  local new_content, count = content:gsub(pattern, '%1' .. new_value, 1)

  if count == 0 then return false end
  return utils.write_file(filepath, new_content)
end

-- Update source paths in all history files in a folder
-- Used when a prompt file is moved
function M.update_source_paths(history_folder, new_source_path)
  local files = M.get_history_files(history_folder)
  local updated = 0

  for _, filepath in ipairs(files) do
    if M.update_frontmatter_field(filepath, 'source', new_source_path) then
      updated = updated + 1
    end
  end

  return updated
end

-- Rename history folder when prompt file is renamed
-- Also updates source metadata in all contained files
function M.rename_history_folder(old_source_path, new_source_path)
  local old_folder = M.find_history_folder(old_source_path)
  if not old_folder then return false, 0 end

  local new_folder = M.build_history_folder_path(new_source_path)
  if not new_folder then return false, 0 end

  -- Don't rename if same path
  if old_folder == new_folder then return false, 0 end

  -- Check if target exists
  if utils.dir_exists(new_folder) then
    return false, 0, 'Target folder already exists'
  end

  -- Rename folder
  local ok = os.rename(old_folder, new_folder)
  if not ok then return false, 0 end

  -- Update source paths in all history files
  local updated = M.update_source_paths(new_folder, new_source_path)

  return true, updated
end

-- Check if a history file exists for a specific shot number
function M.history_exists_for_shot(source_filepath, shot_num)
  local folder = M.find_history_folder(source_filepath)
  if not folder then return false end

  local history = get_history()
  local formatted = history.format_shot_number(shot_num)
  local pattern = string.format('shot-%s-*.md', formatted)

  local files = vim.fn.globpath(folder, pattern, false, true)
  return #files > 0
end

-- Get info about existing history for a source file
function M.get_history_info(source_filepath)
  local folder = M.find_history_folder(source_filepath)
  if not folder then
    return { exists = false, folder = nil, count = 0, shots = {} }
  end

  local files = M.get_history_files(folder)
  local shots = {}

  for _, filepath in ipairs(files) do
    local filename = vim.fn.fnamemodify(filepath, ':t')
    local shot_num = filename:match('^shot%-(%d+)')
    if shot_num then
      shots[tonumber(shot_num)] = filepath
    end
  end

  return {
    exists = true,
    folder = folder,
    count = #files,
    shots = shots,
  }
end

return M

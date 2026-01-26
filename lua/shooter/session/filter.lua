-- Session filter - Apply folder and project filters to file lists
-- Implements whitelist-based filtering

local M = {}

local defaults = require('shooter.session.defaults')

-- Known folder names (subdirectories of plans/prompts/)
local FOLDER_NAMES = defaults.get_folder_names()

-- Detect which folder a file belongs to
-- Files in plans/prompts/<folder>/ belong to that folder
-- Files directly in plans/prompts/ belong to "prompts"
---@param filepath string Full file path
---@return string Folder name ('prompts', 'archive', 'backlog', etc.)
function M.detect_file_folder(filepath)
  -- Check for known subdirectories
  for _, folder in ipairs(FOLDER_NAMES) do
    if folder ~= 'prompts' then
      local pattern = '/plans/prompts/' .. folder .. '/'
      if filepath:find(pattern, 1, true) then
        return folder
      end
    end
  end
  -- Files directly in plans/prompts/ are "prompts"
  if filepath:find('/plans/prompts/[^/]+%.md$') then
    return 'prompts'
  end
  return 'prompts' -- default
end

-- Detect which project a file belongs to
-- Returns nil for root project, project name for subprojects
---@param filepath string Full file path
---@param git_root string|nil Git root path
---@return string|nil Project name or nil for root
function M.detect_file_project(filepath, git_root)
  if not git_root then return nil end
  -- Check if file is in projects/<name>/plans/prompts/
  local pattern = vim.pesc(git_root) .. '/projects/([^/]+)/'
  local project_name = filepath:match(pattern)
  return project_name
end

-- Apply folder whitelist filter
-- Only keeps files from folders that are enabled (true)
---@param files table[] Array of file entries {path, display, ...}
---@param folders_config table Folder -> boolean mapping
---@return table[] Filtered files
function M.apply_folder_filter(files, folders_config)
  local result = {}
  for _, file in ipairs(files) do
    local folder = M.detect_file_folder(file.path)
    if folders_config[folder] then
      table.insert(result, file)
    end
  end
  return result
end

-- Apply project whitelist filter
-- Keeps files from root project (if enabled) and specified subprojects
---@param files table[] Array of file entries {path, display, project, ...}
---@param projects_config table {rootProject: bool, subProjects: string[]}
---@param git_root string|nil Git root path
---@return table[] Filtered files
function M.apply_project_filter(files, projects_config, git_root)
  local result = {}

  -- Build set of allowed projects for fast lookup
  local allowed_subs = {}
  for _, sub in ipairs(projects_config.subProjects or {}) do
    allowed_subs[sub] = true
  end

  for _, file in ipairs(files) do
    local project = M.detect_file_project(file.path, git_root)
    if project == nil then
      -- Root project
      if projects_config.rootProject then
        table.insert(result, file)
      end
    else
      -- Subproject
      if allowed_subs[project] then
        table.insert(result, file)
      end
    end
  end
  return result
end

-- Apply all filters from session
---@param files table[] Array of file entries
---@param session table Session object with filters
---@param git_root string|nil Git root path
---@return table[] Filtered files
function M.apply_filters(files, session, git_root)
  if not session or not session.filters then
    return files
  end

  local result = files

  -- Apply folder filter
  if session.filters.folders then
    result = M.apply_folder_filter(result, session.filters.folders)
  end

  -- Apply project filter
  if session.filters.projects then
    result = M.apply_project_filter(result, session.filters.projects, git_root)
  end

  return result
end

-- Get active folder names (for display in title)
---@param session table Session object
---@return string[] List of active folder names
function M.get_active_folders(session)
  local active = {}
  if session and session.filters and session.filters.folders then
    for _, folder in ipairs(FOLDER_NAMES) do
      if session.filters.folders[folder] then
        table.insert(active, folder)
      end
    end
  end
  return active
end

-- Build filter status string for display
---@param session table Session object
---@return string Status string (e.g., "prompts+archive")
function M.get_filter_status(session)
  local folders = M.get_active_folders(session)
  if #folders == 0 then
    return 'none'
  elseif #folders == 1 then
    return folders[1]
  elseif #folders == #FOLDER_NAMES then
    return 'all'
  else
    return table.concat(folders, '+')
  end
end

return M

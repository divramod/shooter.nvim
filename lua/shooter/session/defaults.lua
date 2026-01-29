-- Session defaults and validation
-- Provides DEFAULT session template and helper functions

local M = {}

-- Default session structure
-- Used when creating new sessions or resetting
M.DEFAULT = {
  name = 'init',
  vimMode = {
    shotfilePicker = 'insert',
    projectPicker = 'insert',
    sortPicker = 'insert',
  },
  layout = 'vertical', -- 'vertical' (preview top) or 'horizontal' (preview right)
  filters = {
    projects = {
      rootProject = true,
      subProjects = {}, -- empty = NONE (must explicitly list to include)
    },
    folders = {
      archive = false,
      backlog = false,
      done = false,
      reqs = false,
      wait = false,
      prompts = true,
    },
  },
  sortBy = {
    created = { enabled = false, priority = 0, ascending = true },
    filename = { enabled = true, priority = 1, ascending = true },
    modified = { enabled = false, priority = 0, ascending = false },
    path = { enabled = false, priority = 0, ascending = true },
    projectname = { enabled = false, priority = 0, ascending = true },
    shotcount = { enabled = false, priority = 0, ascending = false },
  },
}

-- Deep copy a table
local function deep_copy(orig)
  if type(orig) ~= 'table' then
    return orig
  end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = deep_copy(v)
  end
  return copy
end

-- Create a new session with given name based on DEFAULT
---@param name string Session name
---@return table Session object
function M.create_session(name)
  local session = deep_copy(M.DEFAULT)
  session.name = name or 'init'
  return session
end

-- Validate and fill missing keys in a session
-- Ensures all required fields exist with proper defaults
---@param session table Session to validate
---@return table Validated session
function M.validate_session(session)
  if not session then
    return deep_copy(M.DEFAULT)
  end

  session.name = session.name or 'init'

  -- Ensure vimMode exists with defaults
  session.vimMode = session.vimMode or {}
  session.vimMode.shotfilePicker = session.vimMode.shotfilePicker or 'insert'
  session.vimMode.projectPicker = session.vimMode.projectPicker or 'insert'
  session.vimMode.sortPicker = session.vimMode.sortPicker or 'insert'
  session.layout = session.layout or 'vertical'

  session.filters = session.filters or {}
  session.filters.projects = session.filters.projects or {}
  session.filters.projects.rootProject = session.filters.projects.rootProject ~= false
  session.filters.projects.subProjects = session.filters.projects.subProjects or {}
  session.filters.folders = session.filters.folders or {}

  -- Ensure all folder keys exist
  for folder, default_val in pairs(M.DEFAULT.filters.folders) do
    if session.filters.folders[folder] == nil then
      session.filters.folders[folder] = default_val
    end
  end

  session.sortBy = session.sortBy or {}
  -- Ensure all sort criteria exist
  for criterion, default_val in pairs(M.DEFAULT.sortBy) do
    if not session.sortBy[criterion] then
      session.sortBy[criterion] = deep_copy(default_val)
    else
      session.sortBy[criterion].enabled = session.sortBy[criterion].enabled or false
      session.sortBy[criterion].priority = session.sortBy[criterion].priority or 0
      if session.sortBy[criterion].ascending == nil then
        session.sortBy[criterion].ascending = default_val.ascending
      end
    end
  end

  return session
end

-- Reset folders to DEFAULT settings (only prompts enabled)
---@return table Default folder configuration
function M.reset_folders()
  return deep_copy(M.DEFAULT.filters.folders)
end

-- Reset sortBy to DEFAULT settings
---@return table Default sortBy configuration
function M.reset_sortBy()
  return deep_copy(M.DEFAULT.sortBy)
end

-- Get list of all folder names
---@return string[] List of folder names
function M.get_folder_names()
  return { 'archive', 'backlog', 'done', 'reqs', 'wait', 'prompts' }
end

-- Get list of all sort criteria names
---@return string[] List of sort criteria names
function M.get_sort_criteria()
  return { 'created', 'filename', 'modified', 'path', 'projectname', 'shotcount' }
end

return M

-- Session lifecycle management
-- Provides current session state and modification functions

local M = {}

local storage = require('shooter.session.storage')
local defaults = require('shooter.session.defaults')
local files_mod = require('shooter.core.files')

-- In-memory state
M._current_session = nil
M._current_repo_slug = nil
M._last_session_name = nil -- Track last loaded session per repo

-- Get current git root
---@return string|nil Git root path
local function get_git_root()
  return files_mod.get_git_root()
end

-- Get current repo slug
---@return string Repo slug
function M.get_repo_slug()
  local git_root = get_git_root()
  return storage.get_repo_slug(git_root)
end

-- Get or create current session
-- Loads last used session or creates init if none exists
---@return table Current session
function M.get_current_session()
  local repo_slug = M.get_repo_slug()

  -- If repo changed, reload session
  if repo_slug ~= M._current_repo_slug then
    M._current_session = nil
    M._current_repo_slug = repo_slug
  end

  -- Return cached session if available
  if M._current_session then
    return M._current_session
  end

  -- Try to load last session from metadata file
  local last_name = M._get_last_session_name(repo_slug)
  if last_name then
    local session = storage.read_session(repo_slug, last_name)
    if session then
      M._current_session = session
      return M._current_session
    end
  end

  -- Fall back to init session
  M._current_session = storage.ensure_init_session(repo_slug)
  M._save_last_session_name(repo_slug, M._current_session.name)
  return M._current_session
end

-- Get/save last session name for repo
function M._get_last_session_name(repo_slug)
  local file = io.open(storage.get_sessions_dir(repo_slug) .. '/.last', 'r')
  if not file then return nil end
  local name = file:read('*l'); file:close(); return name
end

function M._save_last_session_name(repo_slug, name)
  local dir = storage.get_sessions_dir(repo_slug); vim.fn.mkdir(dir, 'p')
  local file = io.open(dir .. '/.last', 'w')
  if file then file:write(name); file:close() end
end

-- Load a specific session by name
---@param name string Session name to load
---@return boolean Success
function M.load_session(name)
  local repo_slug = M.get_repo_slug()
  local session = storage.read_session(repo_slug, name)
  if session then
    M._current_session = session
    M._save_last_session_name(repo_slug, name)
    return true
  end
  return false
end

-- Save current session to storage
function M.save_current()
  if not M._current_session then return end
  local repo_slug = M.get_repo_slug()
  storage.write_session(repo_slug, M._current_session)
end

-- Toggle folder filter and auto-save
function M.toggle_folder(folder)
  local folders = M.get_current_session().filters.folders
  folders[folder] = not (folders[folder] or false); M.save_current(); return folders[folder]
end

-- Set projects filter and auto-save
function M.set_projects(root_project, sub_projects)
  local proj = M.get_current_session().filters.projects
  proj.rootProject = root_project; proj.subProjects = sub_projects or {}; M.save_current()
end

-- Reset folders to DEFAULT and auto-save
function M.reset_folders()
  M.get_current_session().filters.folders = defaults.reset_folders(); M.save_current()
end

-- Check if all folders are enabled
function M.all_folders_enabled()
  local folders = M.get_current_session().filters.folders
  for _, f in ipairs(defaults.get_folder_names()) do if not folders[f] then return false end end
  return true
end

-- Toggle between all folders and prompts-only
function M.toggle_all_folders()
  if M.all_folders_enabled() then M.reset_folders(); return false end
  local folders = M.get_current_session().filters.folders
  for _, f in ipairs(defaults.get_folder_names()) do folders[f] = true end
  M.save_current(); return true
end

-- Create new session with DEFAULT settings
---@param name string Session name
---@return table New session
function M.create_new_session(name)
  local repo_slug = M.get_repo_slug()
  local session = defaults.create_session(name)
  storage.write_session(repo_slug, session)
  M._current_session = session
  M._save_last_session_name(repo_slug, name)
  return session
end

-- Delete current session and reload init
---@return boolean Success
function M.delete_current_session()
  if not M._current_session then return false end
  local repo_slug = M.get_repo_slug()
  local name = M._current_session.name
  storage.delete_session(repo_slug, name)
  -- Load init session (will auto-create if deleted)
  M._current_session = nil
  M.get_current_session()
  return true
end

-- Rename current session
---@param new_name string New session name
---@return boolean Success
function M.rename_current_session(new_name)
  if not M._current_session then return false end
  local repo_slug = M.get_repo_slug()
  local old_name = M._current_session.name
  if storage.rename_session(repo_slug, old_name, new_name) then
    M._current_session.name = new_name
    M._save_last_session_name(repo_slug, new_name)
    return true
  end
  return false
end

-- List all available sessions
---@return string[] Session names
function M.list_sessions()
  local repo_slug = M.get_repo_slug()
  return storage.list_sessions(repo_slug)
end

-- Get current session name
function M.get_current_session_name()
  return M.get_current_session().name
end

-- Toggle layout between horizontal and vertical
function M.toggle_layout()
  local sess = M.get_current_session()
  sess.layout = sess.layout == 'horizontal' and 'vertical' or 'horizontal'
  M.save_current(); return sess.layout
end

-- Get path to current session YAML file
function M.get_session_file_path()
  local repo_slug = M.get_repo_slug()
  local session = M.get_current_session()
  return storage.get_sessions_dir(repo_slug) .. '/' .. session.name .. '.yaml'
end

-- Reload current session from disk (for external edits)
function M.reload_from_disk()
  local repo_slug = M.get_repo_slug()
  local name = M._current_session and M._current_session.name or 'init'
  local session = storage.read_session(repo_slug, name)
  if session then M._current_session = session end
end

return M

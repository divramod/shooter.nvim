-- Session storage - YAML I/O and path resolution
-- Handles reading/writing session files to ~/.config/shooter.nvim/sessions/<repo>/

local M = {}
local defaults = require('shooter.session.defaults')

-- Get sanitized repo slug from git root path
---@param git_root string Full path to git root
---@return string Sanitized repo identifier (owner/repo format)
function M.get_repo_slug(git_root)
  if not git_root then
    return 'unknown'
  end
  -- Extract last two path components (owner/repo or just repo)
  local parts = {}
  for part in git_root:gmatch('[^/]+') do
    table.insert(parts, part)
  end
  if #parts >= 2 then
    return parts[#parts - 1] .. '/' .. parts[#parts]
  elseif #parts >= 1 then
    return parts[#parts]
  end
  return 'unknown'
end

-- Get sessions directory for a repo
---@param repo_slug string Repo identifier
---@return string Path to sessions directory
function M.get_sessions_dir(repo_slug)
  local config_dir = vim.fn.expand('~/.config/shooter.nvim/sessions')
  return config_dir .. '/' .. repo_slug:gsub('/', '_')
end

-- Ensure sessions directory exists
---@param sessions_dir string Path to sessions directory
local function ensure_dir(sessions_dir)
  vim.fn.mkdir(sessions_dir, 'p')
end

-- Simple YAML serializer for our known schema
---@param session table Session object
---@return string YAML content
local function serialize_yaml(session)
  local lines = {}
  table.insert(lines, 'name: ' .. session.name)
  table.insert(lines, 'vimMode:')
  table.insert(lines, '  shotfilePicker: ' .. (session.vimMode and session.vimMode.shotfilePicker or 'normal'))
  table.insert(lines, '  projectPicker: ' .. (session.vimMode and session.vimMode.projectPicker or 'normal'))
  table.insert(lines, '  sortPicker: ' .. (session.vimMode and session.vimMode.sortPicker or 'normal'))
  table.insert(lines, 'layout: ' .. (session.layout or 'vertical'))
  table.insert(lines, 'filters:')
  table.insert(lines, '  projects:')
  table.insert(lines, '    rootProject: ' .. tostring(session.filters.projects.rootProject))
  table.insert(lines, '    subProjects:')
  for _, sub in ipairs(session.filters.projects.subProjects) do
    table.insert(lines, '      - ' .. sub)
  end
  table.insert(lines, '  folders:')
  for _, folder in ipairs(defaults.get_folder_names()) do
    local val = session.filters.folders[folder]
    table.insert(lines, '    ' .. folder .. ': ' .. tostring(val == true))
  end
  table.insert(lines, 'sortBy:')
  for _, criterion in ipairs(defaults.get_sort_criteria()) do
    local cfg = session.sortBy[criterion]
    table.insert(lines, '  ' .. criterion .. ':')
    table.insert(lines, '    enabled: ' .. tostring(cfg.enabled == true))
    table.insert(lines, '    priority: ' .. tostring(cfg.priority or 0))
    table.insert(lines, '    ascending: ' .. tostring(cfg.ascending == true))
  end
  return table.concat(lines, '\n') .. '\n'
end

-- Simple YAML parser for our known schema
---@param content string YAML content
---@return table Session object
local function parse_yaml(content)
  local session = defaults.create_session('init')
  local lines = {}
  for line in content:gmatch('[^\n]+') do
    lines[#lines + 1] = line
  end

  local i = 1
  while i <= #lines do
    local line = lines[i]
    -- Parse name
    local name_match = line:match('^name:%s*(.+)$')
    if name_match then
      session.name = name_match:gsub('%s+$', '')
    end
    -- Parse vimMode settings
    local shotfile_mode = line:match('^%s+shotfilePicker:%s*(.+)$')
    if shotfile_mode then
      session.vimMode = session.vimMode or {}
      session.vimMode.shotfilePicker = shotfile_mode:gsub('%s+$', '')
    end
    local project_mode = line:match('^%s+projectPicker:%s*(.+)$')
    if project_mode then
      session.vimMode = session.vimMode or {}
      session.vimMode.projectPicker = project_mode:gsub('%s+$', '')
    end
    local sort_mode = line:match('^%s+sortPicker:%s*(.+)$')
    if sort_mode then
      session.vimMode = session.vimMode or {}
      session.vimMode.sortPicker = sort_mode:gsub('%s+$', '')
    end
    local layout_match = line:match('^layout:%s*(.+)$')
    if layout_match then session.layout = layout_match:gsub('%s+$', '') end
    -- Parse rootProject
    local root_match = line:match('^%s+rootProject:%s*(.+)$')
    if root_match then
      session.filters.projects.rootProject = root_match:match('true') ~= nil
    end
    -- Parse subProjects list items
    local sub_match = line:match('^%s+%-%s*(.+)$')
    if sub_match and i > 1 and lines[i - 1]:match('subProjects') then
      -- Actually need to track context better
    end
    -- Parse folder settings
    for _, folder in ipairs(defaults.get_folder_names()) do
      local folder_match = line:match('^%s+' .. folder .. ':%s*(.+)$')
      if folder_match then
        session.filters.folders[folder] = folder_match:match('true') ~= nil
      end
    end
    -- Parse sortBy settings
    for _, criterion in ipairs(defaults.get_sort_criteria()) do
      if line:match('^%s+' .. criterion .. ':$') then
        -- Next lines contain enabled, priority, ascending
        local j = i + 1
        while j <= #lines and lines[j]:match('^%s%s%s%s') do
          local enabled = lines[j]:match('enabled:%s*(.+)$')
          if enabled then
            session.sortBy[criterion].enabled = enabled:match('true') ~= nil
          end
          local priority = lines[j]:match('priority:%s*(%d+)')
          if priority then
            session.sortBy[criterion].priority = tonumber(priority) or 0
          end
          local ascending = lines[j]:match('ascending:%s*(.+)$')
          if ascending then
            session.sortBy[criterion].ascending = ascending:match('true') ~= nil
          end
          j = j + 1
        end
      end
    end
    i = i + 1
  end

  -- Parse subProjects separately (context-aware)
  local subProjects = {}
  local in_subprojects = false
  for _, line in ipairs(lines) do
    if line:match('subProjects:') then
      in_subprojects = true
    elseif in_subprojects then
      local sub = line:match('^%s+%-%s*(.+)$')
      if sub then
        subProjects[#subProjects + 1] = sub:gsub('%s+$', '')
      elseif not line:match('^%s+%-') and not line:match('^%s*$') then
        in_subprojects = false
      end
    end
  end
  session.filters.projects.subProjects = subProjects

  return defaults.validate_session(session)
end

-- Read session from file
---@param repo_slug string Repo identifier
---@param name string Session name
---@return table|nil Session object or nil if not found
function M.read_session(repo_slug, name)
  local sessions_dir = M.get_sessions_dir(repo_slug)
  local filepath = sessions_dir .. '/' .. name .. '.yaml'
  local file = io.open(filepath, 'r')
  if not file then
    return nil
  end
  local content = file:read('*a')
  file:close()
  return parse_yaml(content)
end

-- Write session to file
---@param repo_slug string Repo identifier
---@param session table Session object
function M.write_session(repo_slug, session)
  local sessions_dir = M.get_sessions_dir(repo_slug)
  ensure_dir(sessions_dir)
  local filepath = sessions_dir .. '/' .. session.name .. '.yaml'
  local content = serialize_yaml(session)
  local file = io.open(filepath, 'w')
  if file then
    file:write(content)
    file:close()
  end
end

-- Ensure init session exists
---@param repo_slug string Repo identifier
---@return table Init session
function M.ensure_init_session(repo_slug)
  local session = M.read_session(repo_slug, 'init')
  if not session then
    session = defaults.create_session('init')
    M.write_session(repo_slug, session)
  end
  return session
end

-- List all sessions for a repo
---@param repo_slug string Repo identifier
---@return string[] List of session names
function M.list_sessions(repo_slug)
  local sessions_dir = M.get_sessions_dir(repo_slug)
  local sessions = {}
  local handle = vim.loop.fs_scandir(sessions_dir)
  if handle then
    while true do
      local name, ftype = vim.loop.fs_scandir_next(handle)
      if not name then break end
      if ftype == 'file' and name:match('%.yaml$') then
        sessions[#sessions + 1] = name:gsub('%.yaml$', '')
      end
    end
  end
  return sessions
end

-- Delete session file
---@param repo_slug string Repo identifier
---@param name string Session name
---@return boolean Success
function M.delete_session(repo_slug, name)
  local sessions_dir = M.get_sessions_dir(repo_slug)
  local filepath = sessions_dir .. '/' .. name .. '.yaml'
  return os.remove(filepath) ~= nil
end

-- Rename session file
---@param repo_slug string Repo identifier
---@param old_name string Current session name
---@param new_name string New session name
---@return boolean Success
function M.rename_session(repo_slug, old_name, new_name)
  local session = M.read_session(repo_slug, old_name)
  if not session then return false end
  session.name = new_name
  M.write_session(repo_slug, session)
  M.delete_session(repo_slug, old_name)
  return true
end

return M

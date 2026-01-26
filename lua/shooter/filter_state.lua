-- Filter state persistence for shooter.nvim
-- Stores current filter and named session presets

local M = {}

local utils = require('shooter.utils')

-- State structure:
-- {
--   current = { folder = "archive", projects = {"proj1"}, sort_mtime = true, session = "my-session" },
--   sessions = {
--     ["my-session"] = { folder = "archive", projects = {"proj1"}, sort_mtime = true }
--   }
-- }

-- Get path to filter state file
function M.get_state_path()
  return utils.expand_path('~/.config/shooter.nvim/filter-state.json')
end

-- Load state from JSON file
function M.load_state()
  local path = M.get_state_path()
  local content = utils.read_file(path)
  if not content then
    return { current = {}, sessions = {} }
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then
    return { current = {}, sessions = {} }
  end
  -- Ensure required keys exist
  data.current = data.current or {}
  data.sessions = data.sessions or {}
  return data
end

-- Save state to JSON file
function M.save_state(state)
  local path = M.get_state_path()
  utils.ensure_dir(utils.get_dirname(path))
  local content = vim.json.encode(state)
  return utils.write_file(path, content)
end

-- Get current filter (returns { folder, projects, sort_mtime } or empty table)
function M.get_current_filter()
  local state = M.load_state()
  return state.current or {}
end

-- Set current filter (merges with existing)
function M.set_current_filter(filter)
  local state = M.load_state()
  state.current = vim.tbl_extend('force', state.current or {}, filter)
  M.save_state(state)
end

-- Clear current filter (keeps session name if loaded from session)
function M.clear_current_filter()
  local state = M.load_state()
  state.current = {}
  M.save_state(state)
end

-- Clear all filters including session reference
function M.clear_all_filters()
  local state = M.load_state()
  state.current = {}
  M.save_state(state)
end

-- Get name of currently loaded session (nil if none)
function M.get_current_session_name()
  local state = M.load_state()
  return state.current and state.current.session
end

-- List all saved sessions (returns array of names)
function M.list_sessions()
  local state = M.load_state()
  local names = {}
  for name, _ in pairs(state.sessions or {}) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Save current filter as named session
function M.save_session(name)
  local state = M.load_state()
  local current = state.current or {}
  -- Save filter values without session reference
  state.sessions[name] = {
    folder = current.folder,
    projects = current.projects,
    sort_mtime = current.sort_mtime,
  }
  -- Update current to reference this session
  state.current.session = name
  M.save_state(state)
end

-- Load session into current filter
function M.load_session(name)
  local state = M.load_state()
  local session = state.sessions[name]
  if not session then
    return false
  end
  state.current = vim.tbl_extend('force', session, { session = name })
  M.save_state(state)
  return true
end

-- Delete a session by name
function M.delete_session(name)
  local state = M.load_state()
  if not state.sessions[name] then
    return false
  end
  state.sessions[name] = nil
  -- Clear session reference if this was the current session
  if state.current and state.current.session == name then
    state.current.session = nil
  end
  M.save_state(state)
  return true
end

return M

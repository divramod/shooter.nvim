-- Auto-generate pane configs from scripts/shell directory
-- Each script becomes a toggleable pane

local M = {}

-- Get git root directory
---@return string|nil
local function get_git_root()
  local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read('*l')
  handle:close()
  return result and result ~= '' and result or nil
end

-- Check if a file is executable
---@param path string
---@return boolean
local function is_executable(path)
  local handle = io.popen(string.format("test -x '%s' && echo yes", path))
  if not handle then
    return false
  end
  local result = handle:read('*l')
  handle:close()
  return result == 'yes'
end

-- Get script name without extension for display
---@param filename string
---@return string
local function get_script_name(filename)
  -- Remove common extensions
  local name = filename:gsub('%.sh$', '')
  name = name:gsub('%.bash$', '')
  name = name:gsub('%.zsh$', '')
  return name
end

-- Scan scripts/shell directory and return pane configs
---@return table[] panes List of pane configs
function M.get_script_panes()
  local git_root = get_git_root()
  if not git_root then
    return {}
  end

  local scripts_dir = git_root .. '/scripts/shell'

  -- Check if directory exists
  local dir_check = io.popen(string.format("test -d '%s' && echo yes", scripts_dir))
  if not dir_check then
    return {}
  end
  local dir_exists = dir_check:read('*l')
  dir_check:close()

  if dir_exists ~= 'yes' then
    return {}
  end

  -- List files in directory
  local handle = io.popen(string.format("ls -1 '%s' 2>/dev/null", scripts_dir))
  if not handle then
    return {}
  end

  local panes = {}
  for filename in handle:lines() do
    local filepath = scripts_dir .. '/' .. filename
    -- Only include executable files
    if is_executable(filepath) then
      local script_name = get_script_name(filename)
      panes[#panes + 1] = {
        name = 'script:' .. script_name,
        commands = { filepath },
        height = 30,
        focus = true,
        auto_generated = true,
      }
    end
  end
  handle:close()

  return panes
end

return M

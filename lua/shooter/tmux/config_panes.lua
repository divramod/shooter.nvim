-- Configuration loading for toggle panes
-- Parses .shooter.nvim/tmux.yml for pane definitions

local M = {}

-- Cache: { [git_root] = { config = {...}, mtime = number } }
local cache = {}

-- Get the tmux.yml path for a git root
---@param git_root string
---@return string
local function get_config_path(git_root)
  return git_root .. '/.shooter.nvim/tmux.yml'
end

-- Get file modification time
---@param filepath string
---@return number|nil
local function get_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat and stat.mtime.sec or nil
end

-- Parse a simple YAML list of panes
-- Expected format:
-- panes:
--   - name: test1
--     commands:
--     - echo "hello"
--     height: 30
---@param content string
---@return table[] List of pane configs
local function parse_yaml(content)
  local panes = {}
  local current_pane = nil
  local in_commands = false

  -- Split content into lines
  local lines = {}
  for line in content:gmatch('[^\r\n]+') do
    lines[#lines + 1] = line
  end

  for _, line in ipairs(lines) do
    -- Skip empty lines and comments
    if line:match('^%s*$') or line:match('^%s*#') then
      -- skip
    -- Start of a new pane (list item with name)
    elseif line:match('%-%s*name:') then
      -- Save previous pane
      if current_pane and current_pane.name then
        panes[#panes + 1] = current_pane
      end
      -- Extract name
      local name = line:match('name:%s*(.+)$')
      current_pane = {
        name = name and name:gsub('%s+$', '') or 'unnamed',
        commands = {},
        height = 30,
      }
      in_commands = false
    elseif current_pane then
      -- Check for commands section start
      if line:match('^%s*commands:%s*$') then
        in_commands = true
      -- Check for height
      elseif line:match('height:') then
        local height = line:match('height:%s*(%d+)')
        if height then
          current_pane.height = tonumber(height) or 30
        end
        in_commands = false
      -- Check for command list item (line with dash that's NOT a name line)
      elseif in_commands and line:match('^%s*%-') and not line:match('name:') then
        local cmd = line:match('^%s*%-%s*(.+)$')
        if cmd then
          current_pane.commands[#current_pane.commands + 1] = cmd:gsub('%s+$', '')
        end
      end
    end
  end

  -- Don't forget the last pane
  if current_pane and current_pane.name then
    panes[#panes + 1] = current_pane
  end

  return panes
end

-- Load config from file
---@param git_root string
---@return table[]|nil List of pane configs, or nil if no config
function M.load(git_root)
  if not git_root then
    return nil
  end

  local config_path = get_config_path(git_root)
  local mtime = get_mtime(config_path)

  if not mtime then
    -- No config file
    cache[git_root] = nil
    return nil
  end

  -- Check cache
  local cached = cache[git_root]
  if cached and cached.mtime == mtime then
    return cached.config
  end

  -- Read and parse
  local file = io.open(config_path, 'r')
  if not file then
    return nil
  end

  local content = file:read('*a')
  file:close()

  local config = parse_yaml(content)
  cache[git_root] = { config = config, mtime = mtime }

  return config
end

-- Get config for current buffer's git root
---@return table[]|nil
function M.get_current()
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  return M.load(git_root)
end

-- Find a pane config by name
---@param name string
---@return table|nil
function M.find_by_name(name)
  local config = M.get_current()
  if not config then
    return nil
  end

  for _, pane in ipairs(config) do
    if pane.name == name then
      return pane
    end
  end
  return nil
end

-- Clear cache (useful for testing)
function M.clear_cache()
  cache = {}
end

return M

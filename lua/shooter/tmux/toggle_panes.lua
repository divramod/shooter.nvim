-- Toggle panes - show/hide configured panes from tmux.yml
-- Panes persist when hidden (broken to separate window)

local M = {}

local config_panes = require('shooter.tmux.config_panes')
local detect = require('shooter.tmux.detect')
local utils = require('shooter.utils')

-- State tracking: { [name] = { pane_id, window_id, last_height, commands_run } }
-- pane_id: tmux pane ID when visible
-- window_id: tmux window ID when hidden (pane broken to separate window)
-- last_height: remembered height percentage
-- commands_run: boolean, true if initial commands have been executed
local state = {}

-- Execute tmux command and return output
---@param cmd string
---@return string|nil
local function tmux_exec(cmd)
  local handle = io.popen(cmd .. ' 2>/dev/null')
  if not handle then
    return nil
  end
  local result = handle:read('*l')
  handle:close()
  return result
end

-- Execute tmux command without capturing output
---@param cmd string
local function tmux_run(cmd)
  os.execute(cmd .. ' 2>/dev/null')
end

-- Get current pane height as percentage
---@param pane_id string
---@return number
local function get_pane_height_percent(pane_id)
  local height = tmux_exec(string.format(
    "tmux display -p -t %s '#{pane_height}'",
    pane_id
  ))
  local window_height = tmux_exec("tmux display -p '#{window_height}'")

  if height and window_height then
    local h = tonumber(height) or 0
    local wh = tonumber(window_height) or 1
    return math.floor((h / wh) * 100)
  end
  return 30
end

-- Check if a window exists
---@param window_id string
---@return boolean
local function window_exists(window_id)
  local result = tmux_exec(string.format(
    "tmux list-windows -F '#{window_id}' 2>/dev/null | grep -q '%s' && echo yes",
    window_id
  ))
  return result == 'yes'
end

-- Check if a pane exists
---@param pane_id string
---@return boolean
local function pane_exists(pane_id)
  local result = tmux_exec(string.format(
    "tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q '%s' && echo yes",
    pane_id
  ))
  return result == 'yes'
end

-- Create a new pane at the bottom with given height percentage
---@param height number Height percentage (1-100)
---@return string|nil pane_id
local function create_bottom_pane(height)
  -- Use -l with % suffix for tmux 3.4+ compatibility (replaces deprecated -p)
  local pane_id = tmux_exec(string.format(
    "tmux split-window -v -l %d%% -P -F '#{pane_id}'",
    height
  ))
  return pane_id and pane_id ~= '' and pane_id or nil
end

-- Run commands in a pane
---@param pane_id string
---@param commands string[]
local function run_commands(pane_id, commands)
  for _, cmd in ipairs(commands) do
    -- Escape single quotes in the command
    local escaped = cmd:gsub("'", "'\\''")
    tmux_run(string.format("tmux send-keys -t %s '%s' Enter", pane_id, escaped))
    -- Small delay between commands
    vim.wait(100, function() return false end, 50)
  end
end

-- Hide a pane by breaking it to a new window
---@param name string Pane name
---@return boolean success
function M.hide(name)
  local pane_state = state[name]
  if not pane_state or not pane_state.pane_id then
    utils.notify('Pane "' .. name .. '" is not visible', vim.log.levels.WARN)
    return false
  end

  -- Check pane still exists
  if not pane_exists(pane_state.pane_id) then
    state[name] = nil
    utils.notify('Pane "' .. name .. '" no longer exists', vim.log.levels.WARN)
    return false
  end

  -- Remember current height before hiding
  pane_state.last_height = get_pane_height_percent(pane_state.pane_id)

  -- Break pane to a new window (stays in background with -d)
  tmux_run(string.format("tmux break-pane -d -t %s", pane_state.pane_id))

  -- Get the window ID of the newly created window (last one)
  local window_id = tmux_exec("tmux list-windows -F '#{window_id}' | tail -1")

  if window_id and window_id ~= '' then
    pane_state.window_id = window_id
    pane_state.pane_id = nil
    utils.notify('Pane "' .. name .. '" hidden', vim.log.levels.INFO)
    return true
  end

  utils.notify('Failed to track hidden pane', vim.log.levels.ERROR)
  return false
end

-- Show a pane (create new or restore from hidden)
---@param name string Pane name
---@return boolean success
function M.show(name)
  -- Check tmux is available
  if not detect.check_tmux_installed() or not detect.in_tmux() then
    utils.notify('Not in tmux', vim.log.levels.WARN)
    return false
  end

  -- Get pane config
  local config = config_panes.find_by_name(name)
  if not config then
    utils.notify('Pane "' .. name .. '" not found in config', vim.log.levels.ERROR)
    return false
  end

  local pane_state = state[name] or {}
  state[name] = pane_state

  -- If pane is already visible, just notify
  if pane_state.pane_id and pane_exists(pane_state.pane_id) then
    utils.notify('Pane "' .. name .. '" is already visible', vim.log.levels.INFO)
    return true
  end

  -- If pane is hidden, restore it
  if pane_state.window_id and window_exists(pane_state.window_id) then
    local height = pane_state.last_height or config.height or 30

    -- Join the pane back from the hidden window
    -- -v = vertical (below), -l = size in lines/percent
    tmux_run(string.format(
      "tmux join-pane -v -l %d%% -s %s",
      height,
      pane_state.window_id
    ))

    -- Get the pane ID of the joined pane (it's now the active one in current window)
    local pane_id = tmux_exec("tmux display -p '#{pane_id}'")

    pane_state.pane_id = pane_id
    pane_state.window_id = nil
    utils.notify('Pane "' .. name .. '" shown', vim.log.levels.INFO)
    return true
  end

  -- Create new pane
  local height = config.height or 30
  local pane_id = create_bottom_pane(height)

  if not pane_id then
    utils.notify('Failed to create pane', vim.log.levels.ERROR)
    return false
  end

  pane_state.pane_id = pane_id
  pane_state.last_height = height

  -- Run commands if not already run
  if not pane_state.commands_run and config.commands and #config.commands > 0 then
    run_commands(pane_id, config.commands)
    pane_state.commands_run = true
  end

  utils.notify('Pane "' .. name .. '" created', vim.log.levels.INFO)
  return true
end

-- Toggle a pane's visibility
---@param name string Pane name
---@return boolean success
function M.toggle(name)
  local pane_state = state[name]

  -- If visible, hide it
  if pane_state and pane_state.pane_id and pane_exists(pane_state.pane_id) then
    return M.hide(name)
  end

  -- Otherwise show it
  return M.show(name)
end

-- Check if a pane is currently visible
---@param name string Pane name
---@return boolean
function M.is_visible(name)
  local pane_state = state[name]
  return pane_state ~= nil
    and pane_state.pane_id ~= nil
    and pane_exists(pane_state.pane_id)
end

-- Check if a pane is hidden (exists but not visible)
---@param name string Pane name
---@return boolean
function M.is_hidden(name)
  local pane_state = state[name]
  return pane_state ~= nil
    and pane_state.window_id ~= nil
    and window_exists(pane_state.window_id)
end

-- Get list of visible pane names
---@return string[]
function M.get_visible_panes()
  local visible = {}
  for name, pane_state in pairs(state) do
    if pane_state.pane_id and pane_exists(pane_state.pane_id) then
      table.insert(visible, name)
    end
  end
  return visible
end

-- Get state for a pane (for debugging/testing)
---@param name string
---@return table|nil
function M.get_state(name)
  return state[name]
end

-- Clear all state (useful for testing)
function M.clear_state()
  state = {}
end

return M

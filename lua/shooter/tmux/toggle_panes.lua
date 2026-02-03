-- Toggle panes - show/hide configured panes from tmux.yml
-- Panes persist when hidden (moved to dedicated hidden session)

local M = {}

local config_panes = require('shooter.tmux.config_panes')
local detect = require('shooter.tmux.detect')
local hidden_session = require('shooter.tmux.hidden_session')
local utils = require('shooter.utils')

-- State tracking: { [name] = { pane_id, window_name, last_height, commands_run, folder } }
-- pane_id: tmux pane ID when visible
-- window_name: window name in hidden session when hidden
-- last_height: remembered height percentage
-- commands_run: boolean, true if initial commands have been executed
-- folder: folder name used in window naming
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

-- Check if a pane exists in the current session (not globally)
---@param pane_id string
---@return boolean
local function pane_exists(pane_id)
  -- Only check current session's panes, not all panes (-a would include hidden session)
  local result = tmux_exec(string.format(
    "tmux list-panes -s -F '#{pane_id}' 2>/dev/null | grep -q '%s' && echo yes",
    pane_id
  ))
  return result == 'yes'
end

-- Create a new pane at the bottom with given height percentage
---@param height number Height percentage (1-100)
---@param focus boolean Whether to focus the new pane (default: true)
---@return string|nil pane_id
local function create_bottom_pane(height, focus)
  -- Use -l with % suffix for tmux 3.4+ compatibility (replaces deprecated -p)
  -- Use -d to not switch focus to the new pane when focus is false
  local flags = focus and '' or '-d '
  local pane_id = tmux_exec(string.format(
    "tmux split-window %s-v -l %d%% -P -F '#{pane_id}'",
    flags,
    height
  ))
  return pane_id and pane_id ~= '' and pane_id or nil
end

-- Get the hidden window name for a pane (includes folder for clarity)
---@param folder string Folder name
---@param name string Pane name
---@return string
local function get_hidden_window_name(folder, name)
  return hidden_session.get_window_name(folder, name)
end

-- Get temp file path for storing pane name
---@param pane_id string
---@return string
local function get_pane_name_file(pane_id)
  -- Remove % prefix from pane_id for filename
  local clean_id = pane_id:gsub('%%', '')
  return '/tmp/shooter-pane-' .. clean_id
end

-- Get temp file path for storing folder name
---@param pane_id string
---@return string
local function get_folder_file(pane_id)
  local clean_id = pane_id:gsub('%%', '')
  return '/tmp/shooter-folder-' .. clean_id
end

-- Set up pane tracking for hiding via tmux keybinding
---@param pane_id string
---@param name string
local function setup_pane_for_hiding(pane_id, name)
  -- Write pane name to temp file so tmux keybinding can read it
  local filepath = get_pane_name_file(pane_id)
  local file = io.open(filepath, 'w')
  if file then
    file:write(name)
    file:close()
  end

  -- Write folder name to temp file
  local folder = hidden_session.get_folder_name()
  local folder_path = get_folder_file(pane_id)
  local folder_file = io.open(folder_path, 'w')
  if folder_file then
    folder_file:write(folder)
    folder_file:close()
  end
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

-- Hide a pane by moving it to the hidden session
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

  -- Get folder name for window naming
  local folder = pane_state.folder or hidden_session.get_folder_name()
  pane_state.folder = folder

  -- Create window name: folder-panename
  local window_name = get_hidden_window_name(folder, name)

  -- Move pane to hidden session
  if hidden_session.hide_pane(pane_state.pane_id, window_name) then
    pane_state.window_name = window_name
    pane_state.pane_id = nil
    utils.notify('Pane "' .. name .. '" hidden', vim.log.levels.INFO)
    return true
  end

  utils.notify('Failed to hide pane', vim.log.levels.ERROR)
  return false
end

-- Show a pane (create new or restore from hidden session)
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

  -- Clear stale pane_id if pane no longer exists in current session
  if pane_state.pane_id and not pane_exists(pane_state.pane_id) then
    pane_state.pane_id = nil
  end

  -- If pane is hidden in the hidden session, restore it
  if pane_state.window_name then
    local height = pane_state.last_height or config.height or 30
    local pane_id = hidden_session.restore_pane(pane_state.window_name, height)

    if pane_id then
      pane_state.pane_id = pane_id
      pane_state.window_name = nil
      hidden_session.cleanup_session()
      utils.notify('Pane "' .. name .. '" shown', vim.log.levels.INFO)
      return true
    end
  end

  -- Check if pane was hidden via tmux keybinding (search by window name)
  local folder = pane_state.folder or hidden_session.get_folder_name()
  local window_name = get_hidden_window_name(folder, name)
  if hidden_session.find_window(window_name) then
    local height = pane_state.last_height or config.height or 30
    local pane_id = hidden_session.restore_pane(window_name, height)

    if pane_id then
      pane_state.pane_id = pane_id
      pane_state.window_name = nil
      pane_state.folder = folder
      hidden_session.cleanup_session()
      utils.notify('Pane "' .. name .. '" shown', vim.log.levels.INFO)
      return true
    end
  end

  -- Create new pane
  local height = config.height or 30
  local focus = config.focus or false
  local pane_id = create_bottom_pane(height, focus)

  if not pane_id then
    utils.notify('Failed to create pane', vim.log.levels.ERROR)
    return false
  end

  pane_state.pane_id = pane_id
  pane_state.last_height = height
  pane_state.folder = folder

  -- Set up environment for tmux keybinding hiding
  setup_pane_for_hiding(pane_id, name)

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

-- Check if a pane is hidden (exists in hidden session)
---@param name string Pane name
---@return boolean
function M.is_hidden(name)
  local pane_state = state[name]
  if pane_state and pane_state.window_name then
    return hidden_session.find_window(pane_state.window_name) ~= nil
  end
  -- Check if hidden via tmux keybinding
  local folder = (pane_state and pane_state.folder) or hidden_session.get_folder_name()
  local window_name = get_hidden_window_name(folder, name)
  return hidden_session.find_window(window_name) ~= nil
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

-- Set up tmux keybinding for toggle panes (opt+shift+A / M-A)
-- This should be called once during plugin setup
-- Note: Requires terminal configured to send Meta for Option key
-- Behavior:
--   - In nvim pane: calls ShooterTmuxTogglePanes command
--   - In toggled pane (created by ShooterTmuxTogglePanes): hides the pane
--   - Otherwise: does nothing
function M.setup_tmux_keybinding()
  if not detect.check_tmux_installed() or not detect.in_tmux() then
    return
  end

  local session_name = hidden_session.get_session_name()

  -- Remove old keybindings from previous versions
  tmux_run("tmux unbind-key H 2>/dev/null")      -- old: prefix + H
  tmux_run("tmux unbind-key -n M-H 2>/dev/null") -- old: opt+shift+H (blocked nvim H)

  -- Create a keybinding that:
  -- 1. If in nvim pane: send command to open toggle panes picker
  -- 2. If in toggled pane (has /tmp/shooter-pane-*): hide the pane
  -- 3. Otherwise: do nothing
  -- The keybinding: opt+shift+A (M-A in tmux terms)
  -- Using -n for root table (no prefix needed)
  local keybind_cmd = string.format([[tmux bind-key -n M-A run-shell '
    PANE_ID=$(tmux display -p "#{pane_id}" | tr -d "%%")
    PANE_CMD=$(tmux display -p "#{pane_current_command}")
    NAME_FILE="/tmp/shooter-pane-$PANE_ID"

    # Check if this is a toggled pane (has marker file)
    if [ -f "$NAME_FILE" ]; then
      NAME=$(cat "$NAME_FILE")
      FOLDER_FILE="/tmp/shooter-folder-$PANE_ID"
      if [ -f "$FOLDER_FILE" ]; then
        FOLDER=$(cat "$FOLDER_FILE")
      else
        FOLDER=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
      fi
      WINDOW_NAME="$FOLDER-$NAME"
      # Ensure hidden session exists
      tmux has-session -t "%s" 2>/dev/null || tmux new-session -d -s "%s" -n "placeholder"
      # Move pane to hidden session
      tmux break-pane -d -t "%s:" -n "$WINDOW_NAME"
    # Check if this is nvim
    elif [ "$PANE_CMD" = "nvim" ] || [ "$PANE_CMD" = "vim" ]; then
      # Send command to nvim to open toggle panes picker
      tmux send-keys -t "%%$PANE_ID" Escape ":ShooterTmuxTogglePanes" Enter
    fi
    # Otherwise do nothing
  ']], session_name, session_name, session_name)
  tmux_run(keybind_cmd)
end

return M

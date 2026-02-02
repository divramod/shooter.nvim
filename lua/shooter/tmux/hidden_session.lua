-- Hidden session management for toggle panes
-- Manages a dedicated tmux session for hidden panes

local M = {}

local HIDDEN_SESSION = 'shooter-hidden-panes'

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

-- Get the hidden session name
---@return string
function M.get_session_name()
  return HIDDEN_SESSION
end

-- Check if the hidden session exists
---@return boolean
function M.session_exists()
  local result = tmux_exec(string.format(
    "tmux has-session -t '%s' 2>/dev/null && echo yes",
    HIDDEN_SESSION
  ))
  return result == 'yes'
end

-- Create the hidden session if it doesn't exist
---@return boolean success
function M.ensure_session()
  if M.session_exists() then
    return true
  end

  -- Create detached session with a placeholder window
  tmux_run(string.format(
    "tmux new-session -d -s '%s' -n 'placeholder'",
    HIDDEN_SESSION
  ))

  return M.session_exists()
end

-- Get the current folder name (last component of git root or cwd)
---@return string
function M.get_folder_name()
  -- Try git root first
  local git_root = tmux_exec("git rev-parse --show-toplevel 2>/dev/null")
  if git_root and git_root ~= '' then
    return git_root:match("([^/]+)$") or 'unknown'
  end

  -- Fall back to current directory name
  local cwd = vim.fn.getcwd()
  return cwd:match("([^/]+)$") or 'unknown'
end

-- Get window name for a hidden pane
---@param folder string Folder name
---@param pane_name string Pane name
---@return string
function M.get_window_name(folder, pane_name)
  return folder .. '-' .. pane_name
end

-- Find a window in the hidden session by name
---@param window_name string
---@return string|nil window_target (session:window format)
function M.find_window(window_name)
  local result = tmux_exec(string.format(
    "tmux list-windows -t '%s' -F '#{window_name}' 2>/dev/null | grep -x '%s'",
    HIDDEN_SESSION,
    window_name
  ))
  if result and result == window_name then
    return HIDDEN_SESSION .. ':' .. window_name
  end
  return nil
end

-- Move a pane to the hidden session
---@param pane_id string Source pane ID
---@param window_name string Name for the window in hidden session
---@return boolean success
function M.hide_pane(pane_id, window_name)
  if not M.ensure_session() then
    return false
  end

  -- Break pane to the hidden session with the given window name
  tmux_run(string.format(
    "tmux break-pane -d -s '%s' -t '%s:' -n '%s'",
    pane_id,
    HIDDEN_SESSION,
    window_name
  ))

  -- Verify window was created
  return M.find_window(window_name) ~= nil
end

-- Restore a pane from the hidden session
---@param window_name string Window name in hidden session
---@param height number Height percentage for the restored pane
---@return string|nil pane_id The new pane ID if successful
function M.restore_pane(window_name, height)
  local window_target = M.find_window(window_name)
  if not window_target then
    return nil
  end

  -- Get the pane ID from the hidden window BEFORE joining
  -- (the window has only one pane, which is the hidden pane)
  local source_pane_id = tmux_exec(string.format(
    "tmux list-panes -t '%s' -F '#{pane_id}'",
    window_target
  ))

  if not source_pane_id or source_pane_id == '' then
    return nil
  end

  -- Get current session and window to join to
  local current_window = tmux_exec("tmux display -p '#{session_name}:#{window_index}'")

  -- Join the pane back to current window
  -- -v = vertical (below), -l = size, -t = target window
  tmux_run(string.format(
    "tmux join-pane -v -l %d%% -s '%s' -t '%s'",
    height,
    window_target,
    current_window or ''
  ))

  -- Verify pane was moved by checking it exists in current session
  local verify = tmux_exec(string.format(
    "tmux list-panes -s -F '#{pane_id}' | grep -q '%s' && echo yes",
    source_pane_id
  ))

  if verify == 'yes' then
    return source_pane_id
  end

  return nil
end

-- Clean up empty hidden session (remove placeholder if only window left)
function M.cleanup_session()
  if not M.session_exists() then
    return
  end

  -- Count windows in hidden session
  local count = tmux_exec(string.format(
    "tmux list-windows -t '%s' 2>/dev/null | wc -l",
    HIDDEN_SESSION
  ))

  local num_windows = tonumber(count) or 0

  -- If only placeholder remains, or session is empty, kill it
  if num_windows <= 1 then
    -- Check if only placeholder exists
    local only_placeholder = tmux_exec(string.format(
      "tmux list-windows -t '%s' -F '#{window_name}' 2>/dev/null | grep -x 'placeholder'",
      HIDDEN_SESSION
    ))
    if only_placeholder == 'placeholder' or num_windows == 0 then
      tmux_run(string.format("tmux kill-session -t '%s' 2>/dev/null", HIDDEN_SESSION))
    end
  end
end

return M

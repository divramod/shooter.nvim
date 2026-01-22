-- Tmux command wrappers for shooter.nvim
-- Provides nvim commands to trigger common tmux operations

local M = {}

-- Execute a tmux command
local function tmux_cmd(cmd)
  local handle = io.popen('tmux ' .. cmd .. ' 2>/dev/null')
  if not handle then
    return nil
  end
  local result = handle:read('*a')
  handle:close()
  return result
end

-- Execute a shell script
local function run_script(script_path)
  local handle = io.popen(script_path .. ' 2>/dev/null')
  if not handle then
    return nil
  end
  local result = handle:read('*a')
  handle:close()
  return result
end

-- Check if we're inside tmux
local function in_tmux()
  return os.getenv('TMUX') ~= nil
end

-- Toggle pane zoom (M-z equivalent)
function M.zoom_toggle()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  tmux_cmd('resize-pane -Z')
end

-- Edit pane content in vim (M-u / d-tmux-edit-vim)
function M.edit_in_vim()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  run_script('d-tmux-edit-vim')
end

-- Toggle git status display (M-G)
function M.git_status_toggle()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  run_script('d-tmux-git-status --toggle')
end

-- Toggle light/dark theme (M-I)
function M.lightswitch()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  -- This needs to run in a split and source config
  tmux_cmd([[split-window "cd ~/dev/scripts && ./d-tmux-lightswitch && sleep 1"]])
  vim.defer_fn(function()
    tmux_cmd('source-file ~/.tmux.conf')
  end, 1500)
end

-- Kill all panes except current (M-O)
function M.kill_other_panes()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  run_script('cd ~/dev/scripts/common && ./tmux_pane_kill_all_execpt_current')
end

-- Reload tmuxp session (M-R)
function M.reload_session()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  local cmd = [[run-shell "echo $(tmux display-message -p '#S') > ~/.tmux.reload" ; ]] ..
              [[run-shell "tmuxp load -y reload" ; ]] ..
              [[run-shell "bash -c \"tmux kill-session -t \\$(cat ~/.tmux.reload)\"" ; ]] ..
              [[run-shell "bash -c \"tmuxp load -y \\$(cat ~/.tmux.reload)\""]]
  tmux_cmd(cmd)
end

-- Delete session picker (M-o)
function M.delete_session()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  tmux_cmd('split-window "cd ~/dev/scripts && ./d-tmux-delete-session"')
end

-- Load smug session (M-t)
function M.smug_load()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  tmux_cmd('split-window "cd ~/dev/scripts && ./d-smug-load"')
end

-- Yank pane content to vim
function M.yank_to_vim()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  run_script('cd ~/dev/scripts/common && ./tmux_yank_pane_to_vim')
end

-- Choose tree/session (M-s)
function M.choose_session()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  tmux_cmd('choose-tree -s')
end

-- Switch to last client (M-P)
function M.switch_last()
  if not in_tmux() then
    vim.notify('Not in tmux session', vim.log.levels.WARN)
    return
  end
  tmux_cmd('switch-client -l')
end

return M

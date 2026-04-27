-- System / terminal / tmux environment checks.
-- Pulled out of shooter/health.lua during plan 0001 phase 004 T006.
-- T008 hardens the shell-outs (table-form vim.fn.system).

local M = {}

function M.check_iterm()
  local term_program = os.getenv('TERM_PROGRAM')
  if term_program ~= 'iTerm.app' then
    vim.health.info('Not running in iTerm', { 'Current terminal: ' .. (term_program or 'unknown') })
    return false
  end
  local version = os.getenv('TERM_PROGRAM_VERSION') or 'unknown'
  vim.health.ok(string.format('iTerm: %s', version))
  return true
end

function M.check_tmux_installed()
  if vim.fn.executable('tmux') ~= 1 then
    vim.health.warn('tmux is not installed or not in PATH', {
      'Install tmux to send shots to Claude panes',
      'macOS: brew install tmux | Ubuntu: sudo apt-get install tmux',
    })
    return false
  end
  -- Table-form to avoid shell parsing of any future PATH-injected tmux argument.
  local out = vim.fn.system({ 'tmux', '-V' })
  local version = (out and out:gsub('\n$', '')) or 'unknown'
  vim.health.ok(string.format('tmux: %s', version))
  return true
end

function M.check_in_tmux()
  local tmux_env = os.getenv('TMUX')
  if not tmux_env then
    vim.health.info('Not running in tmux', {
      'Some features require running Neovim inside tmux',
      'Start tmux with: tmux',
    })
    return false
  end
  vim.health.ok('Running in tmux session')
  return true
end

function M.check_claude_process()
  -- Use vim.fn.system table-form via a sh -c (the pipeline needs a shell).
  -- pgrep is preferable but isn't universally available with the [c] trick;
  -- ps + grep is portable.
  local result = vim.fn.system({ 'sh', '-c', "ps aux | grep '[c]laude'" })
  if not result or result == '' then
    vim.health.info('No Claude process detected', {
      'Ensure Claude CLI is running in a tmux pane',
      'Start Claude with: claude',
    })
    return false
  end
  vim.health.ok('Claude process is running')
  return true
end

return M

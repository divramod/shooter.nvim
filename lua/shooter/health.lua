-- Health check module for shooter.nvim
-- Validates dependencies, configuration, and environment

local M = {}

-- Check if Telescope is available
local function check_telescope()
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.health.error('Telescope not found', {
      'Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim',
    })
    return false
  end

  vim.health.ok('Telescope is installed')
  return true
end

-- Check if tmux is installed
local function check_tmux_installed()
  local result = vim.fn.executable('tmux')
  if result ~= 1 then
    vim.health.warn('tmux is not installed or not in PATH', {
      'Install tmux to send shots to Claude panes',
      'macOS: brew install tmux',
      'Ubuntu: sudo apt-get install tmux',
    })
    return false
  end

  vim.health.ok('tmux is installed')
  return true
end

-- Check if running in tmux
local function check_in_tmux()
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

-- Check if Claude process is running
local function check_claude_process()
  local handle = io.popen("ps aux | grep '[c]laude' 2>/dev/null")
  if not handle then
    vim.health.warn('Could not check for Claude process')
    return false
  end

  local result = handle:read('*a')
  handle:close()

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

-- Check general context file
local function check_general_context()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  local general_context_path = config.get('paths.general_context')
  local expanded_path = utils.expand_path(general_context_path)

  if not utils.file_exists(expanded_path) then
    vim.health.warn(
      string.format('General context file not found: %s', general_context_path),
      {
        'Create the file to provide global context for all projects',
        string.format('mkdir -p %s', vim.fn.fnamemodify(expanded_path, ':h')),
        string.format('touch %s', expanded_path),
      }
    )
    return false
  end

  vim.health.ok(string.format('General context file exists: %s', general_context_path))
  return true
end

-- Check project context file
local function check_project_context()
  local config = require('shooter.config')
  local utils = require('shooter.utils')
  local files = require('shooter.core.files')

  local git_root = files.get_git_root()
  if not git_root then
    vim.health.info('Not in a git repository', {
      'Project context is scoped to git repositories',
    })
    return false
  end

  local project_context_path = config.get('paths.project_context')
  local full_path = git_root .. '/' .. project_context_path

  if not utils.file_exists(full_path) then
    vim.health.info(
      string.format('Project context file not found: %s', project_context_path),
      {
        'Create it to provide project-specific context',
        'Use the template at: templates/shooter-context-project-template.md',
      }
    )
    return false
  end

  vim.health.ok(string.format('Project context file exists: %s', project_context_path))
  return true
end

-- Check prompts directory structure
local function check_prompts_directory()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  local prompts_root = config.get('paths.prompts_root')
  local cwd = utils.cwd()
  local full_path = cwd .. '/' .. prompts_root

  if not utils.dir_exists(full_path) then
    vim.health.warn(
      string.format('Prompts directory not found: %s', prompts_root),
      {
        'Create the directory to store shot files',
        string.format('mkdir -p %s', full_path),
      }
    )
    return false
  end

  vim.health.ok(string.format('Prompts directory exists: %s', prompts_root))

  -- Count markdown files
  local handle = io.popen(string.format('find "%s" -name "*.md" -type f 2>/dev/null | wc -l', full_path))
  if handle then
    local count = handle:read('*a')
    handle:close()
    count = count:gsub('%s+', '')
    vim.health.info(string.format('Found %s shot file(s) in prompts directory', count))
  end

  return true
end

-- Check queue file (if it exists)
local function check_queue_file()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  local queue_file_path = config.get('paths.queue_file')
  local cwd = utils.cwd()
  local full_path = cwd .. '/' .. queue_file_path

  if not utils.file_exists(full_path) then
    vim.health.info(
      string.format('Queue file does not exist: %s', queue_file_path),
      {
        'Queue file will be created automatically when shots are queued',
      }
    )
    return false
  end

  -- Try to validate JSON structure
  local content, err = utils.read_file(full_path)
  if not content then
    vim.health.error(
      string.format('Could not read queue file: %s', err),
      {
        'Check file permissions',
      }
    )
    return false
  end

  local ok, queue = pcall(vim.json.decode, content)
  if not ok then
    vim.health.error(
      string.format('Queue file is not valid JSON: %s', queue_file_path),
      {
        'Delete the file to reset: rm ' .. full_path,
      }
    )
    return false
  end

  if type(queue) ~= 'table' then
    vim.health.error(
      'Queue file does not contain an array',
      {
        'Delete the file to reset: rm ' .. full_path,
      }
    )
    return false
  end

  vim.health.ok(string.format('Queue file is valid (%d item(s))', #queue))
  return true
end

-- Main health check function
function M.check()
  vim.health.start('shooter.nvim')

  -- Check dependencies
  vim.health.start('Dependencies')
  check_telescope()
  local tmux_installed = check_tmux_installed()

  -- Check tmux environment (only if tmux is installed)
  if tmux_installed then
    vim.health.start('Tmux Environment')
    local in_tmux = check_in_tmux()
    if in_tmux then
      check_claude_process()
    end
  end

  -- Check context files
  vim.health.start('Context Files')
  check_general_context()
  check_project_context()

  -- Check directory structure
  vim.health.start('Directory Structure')
  check_prompts_directory()

  -- Check queue
  vim.health.start('Queue System')
  check_queue_file()

  vim.health.start('Summary')
  vim.health.info('Run :help shooter.nvim for usage documentation')
end

return M

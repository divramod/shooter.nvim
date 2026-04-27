-- Shotfile-area checks: prompts directory + queue file.
-- Pulled out of shooter/health.lua during plan 0001 phase 004 T006.
-- T008 hardens the prompts-directory shell-out (table-form vim.fn.systemlist
-- + readdir for the .md count) — replaces an io.popen('find … | wc -l').

local M = {}

local function count_md_files(root)
  -- Replaces `io.popen(string.format('find "%s" -name "*.md" -type f | wc -l', full_path))`.
  -- We don't need the shell; vim.fs.find is recursive.
  local files = vim.fs.find(function(name) return name:match('%.md$') end, {
    path = root, type = 'file', limit = math.huge,
  })
  return #files
end

function M.check_prompts_directory()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  local prompts_root = config.get('paths.prompts_root')
  if not prompts_root then
    vim.health.error('Config error: paths.prompts_root is nil')
    return false
  end

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

  local count = count_md_files(full_path)
  vim.health.info(string.format('Found %d shot file(s) in prompts directory', count))

  return true
end

function M.check_queue_file()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  local queue_file_path = config.get('paths.queue_file')
  if not queue_file_path then
    vim.health.error('Config error: paths.queue_file is nil')
    return false
  end

  local cwd = utils.cwd()
  local full_path = cwd .. '/' .. queue_file_path

  if not utils.file_exists(full_path) then
    vim.health.info(
      string.format('Queue file does not exist: %s', queue_file_path),
      { 'Queue file will be created automatically when shots are queued' }
    )
    return false
  end

  local content, err = utils.read_file(full_path)
  if not content then
    vim.health.error(
      string.format('Could not read queue file: %s', err),
      { 'Check file permissions' }
    )
    return false
  end

  local ok, queue = pcall(vim.json.decode, content)
  if not ok then
    vim.health.error(
      string.format('Queue file is not valid JSON: %s', queue_file_path),
      { 'Delete the file to reset: rm ' .. full_path }
    )
    return false
  end

  if type(queue) ~= 'table' then
    vim.health.error(
      'Queue file does not contain an array',
      { 'Delete the file to reset: rm ' .. full_path }
    )
    return false
  end

  vim.health.ok(string.format('Queue file is valid (%d item(s))', #queue))
  return true
end

return M

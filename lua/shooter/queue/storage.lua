-- Queue storage and persistence
-- Handles JSON file loading and saving for shot queue

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Get queue file path
function M.get_queue_file_path()
  local cwd = utils.cwd()
  local queue_file = config.get('paths.queue_file')
  return cwd .. '/' .. queue_file
end

-- Load queue from JSON file
-- Returns empty table if file doesn't exist or is invalid
function M.load_queue()
  local queue_file = M.get_queue_file_path()

  -- Check if file exists
  if not utils.file_exists(queue_file) then
    return {}
  end

  -- Read file content
  local content, err = utils.read_file(queue_file)
  if not content then
    utils.echo('Failed to read queue file: ' .. (err or 'unknown error'))
    return {}
  end

  -- Handle empty file
  if content == '' or content == '\n' then
    return {}
  end

  -- Parse JSON
  local ok, queue = pcall(vim.json.decode, content)
  if not ok then
    utils.echo('Failed to parse queue file (corrupted JSON)')
    return {}
  end

  return queue or {}
end

-- Save queue to JSON file
-- Creates directory if needed
function M.save_queue(queue)
  local queue_file = M.get_queue_file_path()

  -- Ensure directory exists
  local dir = utils.get_dirname(queue_file)
  utils.ensure_dir(dir)

  -- Encode to JSON
  local ok, json = pcall(vim.json.encode, queue)
  if not ok then
    utils.echo('Failed to encode queue to JSON')
    return false
  end

  -- Write to file
  local success, err = utils.write_file(queue_file, json)
  if not success then
    utils.echo('Failed to save queue: ' .. (err or 'unknown error'))
    return false
  end

  return true
end

-- Check if queue file exists
function M.queue_file_exists()
  local queue_file = M.get_queue_file_path()
  return utils.file_exists(queue_file)
end

-- Delete queue file
function M.delete_queue_file()
  local queue_file = M.get_queue_file_path()
  if utils.file_exists(queue_file) then
    os.remove(queue_file)
    return true
  end
  return false
end

-- Backup queue file
function M.backup_queue()
  local queue_file = M.get_queue_file_path()
  if not utils.file_exists(queue_file) then
    return false, 'Queue file does not exist'
  end

  local timestamp = utils.get_timestamp()
  local backup_file = queue_file .. '.backup.' .. timestamp

  local content, err = utils.read_file(queue_file)
  if not content then
    return false, err
  end

  local success, write_err = utils.write_file(backup_file, content)
  if not success then
    return false, write_err
  end

  return true, backup_file
end

return M

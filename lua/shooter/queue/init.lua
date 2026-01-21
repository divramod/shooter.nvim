-- Queue management for shooter.nvim
-- Manages adding, removing, and viewing shots in the queue

local utils = require('shooter.utils')
local config = require('shooter.config')
local files = require('shooter.core.files')
local storage = require('shooter.queue.storage')

local M = {}

-- Get current queue
function M.get_queue()
  return storage.load_queue()
end

-- Get queue count
function M.get_count()
  local queue = storage.load_queue()
  return #queue
end

-- Find current shot at cursor position
local function find_current_shot()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = utils.get_buf_lines(0, 0, utils.buf_line_count(0))
  local shot_pattern = config.get('patterns.shot_header')

  -- Search backwards from cursor for shot header
  local shot_line = nil
  for i = cursor_line, 1, -1 do
    if lines[i]:match(shot_pattern) then
      shot_line = i
      break
    end
  end

  if not shot_line then return nil end

  local shot_num = lines[shot_line]:match('shot%s+(%d+)')
  if not shot_num then return nil end

  return {
    file = vim.fn.expand('%:p'),
    shot_number = shot_num,
    shot_line = shot_line,
    title = files.get_file_title(0),
  }
end

-- Add shot to queue for specific pane
function M.add_to_queue(shot, pane_num)
  pane_num = pane_num or 1

  if not shot then
    if not files.is_shooter_file(vim.fn.expand('%:p')) then
      utils.echo('Not in a shooter file')
      return false
    end
    shot = find_current_shot()
    if not shot then
      utils.echo('No shot found at cursor')
      return false
    end
  end

  local queue = storage.load_queue()
  table.insert(queue, {
    file = shot.file,
    shot_number = shot.shot_number,
    shot_line = shot.shot_line,
    title = shot.title,
    pane = pane_num,
    timestamp = os.time(),
  })

  if storage.save_queue(queue) then
    utils.echo(string.format('Added shot %s to queue for pane #%d', shot.shot_number, pane_num))
    return true
  end
  return false
end

-- Remove shot from queue by index
function M.remove_from_queue(index)
  local queue = storage.load_queue()
  if index < 1 or index > #queue then
    utils.echo('Invalid queue index')
    return false
  end

  local removed = table.remove(queue, index)
  if storage.save_queue(queue) then
    utils.echo(string.format('Removed shot %s from queue', removed.shot_number))
    return true
  end
  return false
end

-- Clear entire queue
function M.clear_queue()
  if storage.save_queue({}) then
    utils.echo('Queue cleared')
    return true
  end
  return false
end

-- Get queue items for specific pane
function M.get_pane_queue(pane_num)
  local pane_queue = {}
  for _, item in ipairs(storage.load_queue()) do
    if item.pane == pane_num then table.insert(pane_queue, item) end
  end
  return pane_queue
end

-- Get next item in queue (first item)
function M.get_next()
  local queue = storage.load_queue()
  return #queue > 0 and queue[1] or nil, #queue > 0 and 1 or nil
end

-- Get next item for specific pane
function M.get_next_for_pane(pane_num)
  for i, item in ipairs(storage.load_queue()) do
    if item.pane == pane_num then return item, i end
  end
  return nil, nil
end

-- Move queue item to different position
function M.move_item(from_index, to_index)
  local queue = storage.load_queue()
  if from_index < 1 or from_index > #queue then
    utils.echo('Invalid source index')
    return false
  end
  if to_index < 1 or to_index > #queue then
    utils.echo('Invalid destination index')
    return false
  end

  table.insert(queue, to_index, table.remove(queue, from_index))
  if storage.save_queue(queue) then
    utils.echo('Queue item moved')
    return true
  end
  return false
end

-- Update pane for queue item
function M.update_pane(index, new_pane)
  local queue = storage.load_queue()
  if index < 1 or index > #queue then
    utils.echo('Invalid queue index')
    return false
  end

  queue[index].pane = new_pane
  if storage.save_queue(queue) then
    utils.echo(string.format('Updated pane to #%d', new_pane))
    return true
  end
  return false
end

return M

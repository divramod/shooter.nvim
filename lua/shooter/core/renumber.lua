-- Shot renumbering for shooter.nvim
-- Renumber all shots sequentially, sorting done shots by date first

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Parse timestamp from executed shot header
-- Formats: (2026-01-29 07:56:02) or without parens
local function parse_timestamp(header_line)
  local ts = header_line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
  return ts
end

-- Parse shot info from header line
local function parse_shot_info(line)
  local is_done = line:match(config.get('patterns.executed_shot_header')) ~= nil
  local shot_num = line:match('shot%s+(%d+)')
  local timestamp = parse_timestamp(line)
  return {
    is_done = is_done,
    shot_num = tonumber(shot_num) or 0,
    timestamp = timestamp,
  }
end

-- Check if line is inside a code block
local function is_in_code_block(lines, line_num)
  local in_block = false
  for i = 1, line_num - 1 do
    if lines[i]:match('^```') then
      in_block = not in_block
    end
  end
  return in_block
end

-- Find all shots with their line ranges and metadata
local function find_all_shots_with_info(bufnr)
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)
  local shots = {}

  local i = 1
  while i <= total_lines do
    if lines[i]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, i) then
      local shot_start = i
      local shot_end = total_lines

      for j = shot_start + 1, total_lines do
        if lines[j]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, j) then
          shot_end = j - 1
          break
        end
      end

      local info = parse_shot_info(lines[i])
      table.insert(shots, {
        start_line = shot_start,
        end_line = shot_end,
        header_line = shot_start,
        header_text = lines[i],
        is_done = info.is_done,
        timestamp = info.timestamp,
        original_num = info.shot_num,
      })

      i = shot_end + 1
    else
      i = i + 1
    end
  end

  return shots
end

-- Sort shots: done shots by timestamp (oldest first), then open shots
local function sort_shots(shots)
  local done_shots = {}
  local open_shots = {}

  for _, shot in ipairs(shots) do
    if shot.is_done then
      table.insert(done_shots, shot)
    else
      table.insert(open_shots, shot)
    end
  end

  -- Sort done shots by timestamp (oldest first)
  table.sort(done_shots, function(a, b)
    local ts_a = a.timestamp or '0000-00-00 00:00:00'
    local ts_b = b.timestamp or '0000-00-00 00:00:00'
    return ts_a < ts_b
  end)

  -- Combine: done shots first (sorted by date), then open shots (keep order)
  local sorted = {}
  for _, shot in ipairs(done_shots) do table.insert(sorted, shot) end
  for _, shot in ipairs(open_shots) do table.insert(sorted, shot) end

  return sorted
end

-- Generate new header line with updated shot number
-- Handles both "shot 123" and "shot ?" formats
local function update_header_number(header_text, new_num)
  -- First try to replace numeric shot number
  local updated = header_text:gsub('shot%s+%d+', 'shot ' .. new_num)
  if updated ~= header_text then
    return updated
  end
  -- Also handle "shot ?" format
  return header_text:gsub('shot%s+%?', 'shot ' .. new_num)
end

-- Renumber all shots in current buffer
function M.renumber_shots(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local shots = find_all_shots_with_info(bufnr)
  if #shots == 0 then
    utils.notify('No shots found in file', vim.log.levels.INFO)
    return 0
  end

  -- Sort shots
  local sorted_shots = sort_shots(shots)

  -- Build new buffer content
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)

  -- Collect all shot blocks with new numbers
  -- Number in reverse: first shot gets highest number, last shot gets 1
  local total_shots = #sorted_shots
  local blocks = {}
  for i, shot in ipairs(sorted_shots) do
    local new_num = total_shots - i + 1  -- Reverse numbering
    local new_header = update_header_number(shot.header_text, new_num)
    local block_lines = { new_header }
    for i = shot.start_line + 1, shot.end_line do
      table.insert(block_lines, lines[i])
    end
    table.insert(blocks, block_lines)
  end

  -- Get content before first shot (title, etc.)
  local first_shot_line = shots[1].start_line
  local prefix_lines = {}
  for i = 1, first_shot_line - 1 do
    table.insert(prefix_lines, lines[i])
  end

  -- Rebuild buffer
  local new_lines = {}
  for _, line in ipairs(prefix_lines) do
    table.insert(new_lines, line)
  end

  for i, block in ipairs(blocks) do
    -- Add blank line before shot (except first)
    if i > 1 or #prefix_lines > 0 then
      if #new_lines > 0 and new_lines[#new_lines] ~= '' then
        table.insert(new_lines, '')
      end
    end
    for _, line in ipairs(block) do
      table.insert(new_lines, line)
    end
  end

  -- Update buffer
  utils.set_buf_lines(bufnr, 0, total_lines, new_lines)

  -- Only write if buffer has a valid filename and is not a scratch buffer
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' and vim.bo[bufnr].buftype == '' then
    vim.cmd('write')
  end

  return #shots
end

return M

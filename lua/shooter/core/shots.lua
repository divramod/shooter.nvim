-- Shot detection and management for shooter.nvim
-- Finding, marking, and parsing shots in shooter files

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Check if a line is inside a code block (count ``` markers above)
local function is_in_code_block(lines, line_num)
  local in_block = false
  for i = 1, line_num - 1 do
    if lines[i]:match('^```') then
      in_block = not in_block
    end
  end
  return in_block
end

-- Find shot boundaries (returns start_line, end_line, header_line for the current shot)
-- Ignores shot headers inside code blocks
function M.find_current_shot(bufnr, cursor_line)
  bufnr = bufnr or 0
  cursor_line = cursor_line or utils.get_cursor()[1]

  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)

  local shot_start = nil
  local shot_header_line = nil
  local shot_end = total_lines

  -- Find the shot header at or above cursor (skip headers inside code blocks)
  for i = cursor_line, 1, -1 do
    if lines[i]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, i) then
      shot_start = i
      shot_header_line = i
      break
    end
  end

  if not shot_start then
    return nil, nil, nil
  end

  -- Find the next shot header (or end of file), skip headers inside code blocks
  for i = shot_start + 1, total_lines do
    if lines[i]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, i) then
      shot_end = i - 1
      break
    end
  end

  -- Trim trailing empty lines
  while shot_end > shot_start and lines[shot_end]:match('^%s*$') do
    shot_end = shot_end - 1
  end

  return shot_start, shot_end, shot_header_line
end

-- Find all shots in file (both open and executed)
-- Ignores shot headers inside code blocks
function M.find_all_shots(bufnr)
  bufnr = bufnr or 0
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)
  local shots = {}

  local i = 1
  while i <= total_lines do
    -- Skip headers inside code blocks
    if lines[i]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, i) then
      local shot_start = i
      local shot_end = total_lines

      -- Find the next shot header (or end of file), skip headers in code blocks
      for j = shot_start + 1, total_lines do
        if lines[j]:match(config.get('patterns.shot_header')) and not is_in_code_block(lines, j) then
          shot_end = j - 1
          break
        end
      end

      -- Trim trailing empty lines
      while shot_end > shot_start and lines[shot_end]:match('^%s*$') do
        shot_end = shot_end - 1
      end

      -- Check if executed
      local is_executed = lines[i]:match(config.get('patterns.executed_shot_header')) ~= nil

      table.insert(shots, {
        start_line = shot_start,
        end_line = shot_end,
        header_line = shot_start,
        is_executed = is_executed
      })

      i = shot_end + 1
    else
      i = i + 1
    end
  end

  return shots
end

-- Find all open shots (not marked with x) in the file
function M.find_open_shots(bufnr)
  bufnr = bufnr or 0
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)
  local shots = {}

  local i = 1
  while i <= total_lines do
    -- Find open shot header (## shot, not ## x shot)
    if lines[i]:match(config.get('patterns.open_shot_header'))
        and not lines[i]:match(config.get('patterns.executed_shot_header')) then

      local shot_start = i
      local shot_end = total_lines

      -- Find the next shot header (or end of file)
      for j = shot_start + 1, total_lines do
        if lines[j]:match(config.get('patterns.shot_header')) then
          shot_end = j - 1
          break
        end
      end

      -- Trim trailing empty lines
      while shot_end > shot_start and lines[shot_end]:match('^%s*$') do
        shot_end = shot_end - 1
      end

      table.insert(shots, {
        start_line = shot_start,
        end_line = shot_end,
        header_line = shot_start
      })

      i = shot_end + 1
    else
      i = i + 1
    end
  end

  return shots
end

-- Mark shot header as executed with timestamp
function M.mark_shot_executed(bufnr, header_line)
  bufnr = bufnr or 0
  local line = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local timestamp = utils.get_timestamp()

  -- Check if already marked with x
  if line:match(config.get('patterns.executed_shot_header')) then
    -- Already has x, just update/add timestamp
    if line:match('%(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%)') then
      -- Replace existing timestamp
      line = line:gsub('%(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%)', '(' .. timestamp .. ')')
    else
      -- Add timestamp at end
      line = line .. ' (' .. timestamp .. ')'
    end
  else
    -- Add x after ##
    line = line:gsub('^(##)%s+shot', '%1 x shot')
    -- Add timestamp at end
    line = line .. ' (' .. timestamp .. ')'
  end

  utils.set_buf_lines(bufnr, header_line - 1, header_line, { line })

  -- Normalize shot whitespace (remove empty lines after header, ensure one before next)
  local normalize = require('shooter.core.shot_normalize')
  normalize.normalize_shot(bufnr, header_line)

  -- Only write if buffer has a filename
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('write')
  end
end

-- Parse shot header to extract shot number
function M.parse_shot_header(line)
  local num = line:match('shot%s+(%d+)')
  return num or '?'
end

-- Get shot content (excluding the header line itself)
function M.get_shot_content(bufnr, start_line, end_line)
  bufnr = bufnr or 0

  -- Start from line after header
  local content_start = start_line + 1
  if content_start > end_line then
    return ''
  end

  local lines = utils.get_buf_lines(bufnr, content_start - 1, end_line)

  -- Trim leading empty lines
  while #lines > 0 and lines[1]:match('^%s*$') do
    table.remove(lines, 1)
  end

  -- Trim trailing empty lines
  while #lines > 0 and lines[#lines]:match('^%s*$') do
    table.remove(lines, #lines)
  end

  return table.concat(lines, '\n')
end

-- Get next shot number in file
function M.get_next_shot_number(bufnr)
  bufnr = bufnr or 0
  local lines = utils.get_buf_lines(bufnr, 0, -1)
  local max_shot = 0

  for _, line in ipairs(lines) do
    local shot_num = line:match('^##%s+x?%s*shot%s+(%d+)')
    if shot_num then
      local num = tonumber(shot_num)
      if num and num > max_shot then
        max_shot = num
      end
    end
  end

  return max_shot + 1
end

return M

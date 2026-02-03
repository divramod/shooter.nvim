-- Helper functions for renumbering shots before send operations
-- Tracks shots by content hash to relocate them after renumbering

local M = {}

local utils = require('shooter.utils')

-- Get content hash for a shot (first 200 chars of body, excluding header)
function M.get_shot_content_hash(bufnr, start_line, end_line)
  -- start_line is 1-indexed header line, get_buf_lines uses 0-indexed start
  -- Fetch from start_line (0-indexed = start_line, which skips header at start_line-1)
  local lines = utils.get_buf_lines(bufnr, start_line, end_line)
  local content = table.concat(lines, '\n'):sub(1, 200)
  return content
end

-- Find shot by content hash after renumbering
function M.find_shot_by_content(bufnr, content_hash)
  local config = require('shooter.config')
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)

  local i = 1
  while i <= total_lines do
    if lines[i]:match(config.get('patterns.shot_header')) then
      local shot_start = i
      local shot_end = total_lines
      for j = shot_start + 1, total_lines do
        if lines[j]:match(config.get('patterns.shot_header')) then
          shot_end = j - 1
          break
        end
      end
      -- Check if this shot's content matches
      local shot_lines = {}
      for k = shot_start + 1, shot_end do
        table.insert(shot_lines, lines[k])
      end
      local shot_content = table.concat(shot_lines, '\n'):sub(1, 200)
      if shot_content == content_hash then
        return shot_start, shot_end, shot_start
      end
      i = shot_end + 1
    else
      i = i + 1
    end
  end
  return nil, nil, nil
end

-- Renumber and relocate shot by content hash
-- Returns new start_line, end_line, header_line after renumbering
function M.renumber_and_find_shot(bufnr, original_start, original_end)
  local content_hash = M.get_shot_content_hash(bufnr, original_start, original_end)
  require('shooter.core.renumber').renumber_shots(bufnr)
  return M.find_shot_by_content(bufnr, content_hash)
end

-- Find all executed shots in buffer
function M.find_executed_shots(bufnr)
  local config = require('shooter.config')
  local total_lines = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total_lines)
  local executed = {}
  local i = 1
  while i <= total_lines do
    if lines[i]:match(config.get('patterns.executed_shot_header')) then
      local start_line, end_line = i, total_lines
      for j = i + 1, total_lines do
        if lines[j]:match(config.get('patterns.shot_header')) then end_line = j - 1; break end
      end
      table.insert(executed, { start_line = start_line, end_line = end_line, header_line = start_line })
      i = end_line + 1
    else i = i + 1 end
  end
  return executed
end

return M

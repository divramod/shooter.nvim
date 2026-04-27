-- Shot navigation: open + sent shot traversal with wrap-around.

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

function M.goto_next_open_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local open_shots = shots.find_open_shots(bufnr)

  if #open_shots == 0 then
    utils.echo('No open shots')
    return
  end

  for _, shot in ipairs(open_shots) do
    if shot.header_line > cursor_line then
      vim.api.nvim_win_set_cursor(0, { shot.header_line, 0 })
      local shot_num = shots.parse_shot_header(
        utils.get_buf_lines(bufnr, shot.header_line - 1, shot.header_line)[1]
      )
      utils.echo('Shot ' .. shot_num)
      return
    end
  end

  -- Wrap to first open shot.
  local first = open_shots[1]
  vim.api.nvim_win_set_cursor(0, { first.header_line, 0 })
  local shot_num = shots.parse_shot_header(
    utils.get_buf_lines(bufnr, first.header_line - 1, first.header_line)[1]
  )
  utils.echo('Shot ' .. shot_num .. ' (wrapped)')
end

function M.goto_prev_open_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local open_shots = shots.find_open_shots(bufnr)

  if #open_shots == 0 then
    utils.echo('No open shots')
    return
  end

  for i = #open_shots, 1, -1 do
    local shot = open_shots[i]
    if shot.header_line < cursor_line then
      vim.api.nvim_win_set_cursor(0, { shot.header_line, 0 })
      local shot_num = shots.parse_shot_header(
        utils.get_buf_lines(bufnr, shot.header_line - 1, shot.header_line)[1]
      )
      utils.echo('Shot ' .. shot_num)
      return
    end
  end

  -- Wrap to last open shot.
  local last = open_shots[#open_shots]
  vim.api.nvim_win_set_cursor(0, { last.header_line, 0 })
  local shot_num = shots.parse_shot_header(
    utils.get_buf_lines(bufnr, last.header_line - 1, last.header_line)[1]
  )
  utils.echo('Shot ' .. shot_num .. ' (wrapped)')
end

-- Navigate to the most recently sent/executed shot (by timestamp).
function M.goto_latest_sent_shot()
  local bufnr = 0
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  local latest_line = nil
  local latest_timestamp = nil

  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) then
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if timestamp then
        if not latest_timestamp or timestamp > latest_timestamp then
          latest_timestamp = timestamp
          latest_line = i
        end
      end
    end
  end

  if not latest_line then
    utils.echo('No sent shots found')
    return
  end

  vim.api.nvim_win_set_cursor(0, { latest_line, 0 })
  local shot_num = shots.parse_shot_header(lines[latest_line])
  utils.echo('Latest sent: Shot ' .. shot_num .. ' (' .. latest_timestamp .. ')')
end

-- Get all sent shots sorted by timestamp (oldest first).
-- Supports both old format (no @ref) and new format (with @ref at end).
local function get_sent_shots_sorted(bufnr)
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)
  local sent = {}
  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) then
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if ts then table.insert(sent, { line_num = i, timestamp = ts, shot_num = shots.parse_shot_header(line) }) end
    end
  end
  table.sort(sent, function(a, b) return a.timestamp < b.timestamp end)
  return sent
end

function M.goto_prev_sent_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local sent = get_sent_shots_sorted(bufnr)
  if #sent == 0 then utils.echo('No sent shots'); return end

  local current_idx = nil
  for i, s in ipairs(sent) do
    if s.line_num == cursor_line then current_idx = i; break end
  end

  local target
  if current_idx and current_idx > 1 then
    target = sent[current_idx - 1]
  else
    target = sent[#sent]  -- Wrap to newest if at oldest or not on a sent shot.
  end

  vim.api.nvim_win_set_cursor(0, { target.line_num, 0 })
  utils.echo('Shot ' .. target.shot_num .. ' (' .. target.timestamp .. ')')
end

function M.goto_next_sent_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local sent = get_sent_shots_sorted(bufnr)
  if #sent == 0 then utils.echo('No sent shots'); return end

  local current_idx = nil
  for i, s in ipairs(sent) do
    if s.line_num == cursor_line then current_idx = i; break end
  end

  local target
  if current_idx and current_idx < #sent then
    target = sent[current_idx + 1]
  else
    target = sent[1]  -- Wrap to oldest if at newest or not on a sent shot.
  end

  vim.api.nvim_win_set_cursor(0, { target.line_num, 0 })
  utils.echo('Shot ' .. target.shot_num .. ' (' .. target.timestamp .. ')')
end

return M

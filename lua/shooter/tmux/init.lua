-- Tmux integration module for shooter.nvim
-- Main entry point for tmux functionality

local M = {}

-- Lazy load submodules
M.detect = require('shooter.tmux.detect')
M.send = require('shooter.tmux.send')
M.messages = require('shooter.tmux.messages')
M.create = require('shooter.tmux.create')

local operations = require('shooter.tmux.operations')

-- Send current shot to Claude pane
function M.send_current_shot(pane_index)
  operations.send_current_shot(pane_index, M.detect, M.send, M.messages)
end

-- Send all open shots to Claude pane
function M.send_all_shots(pane_index)
  operations.send_all_shots(pane_index, M.detect, M.send, M.messages)
end

-- Send visual selection to Claude pane
function M.send_visual_selection(pane_index, start_line, end_line)
  operations.send_visual_selection(pane_index, start_line, end_line, M.detect, M.send)
end

-- Send specific shots to Claude pane (used by telescope multi-select)
function M.send_specific_shots(pane_index, shot_infos, bufnr)
  operations.send_specific_shots(pane_index, shot_infos, bufnr, M.detect, M.send, M.messages)
end

-- Resend the latest sent shot to a Claude pane
function M.resend_latest_shot(pane_index)
  pane_index = pane_index or 1
  local utils = require('shooter.utils')
  local shots = require('shooter.core.shots')
  local config = require('shooter.config')
  local files = require('shooter.core.files')

  -- Check if we're in a shooter file
  if not files.is_shooter_file() then
    utils.echo('Not in a shooter file')
    return
  end

  local bufnr = utils.current_buf()
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  -- Find the latest sent shot by timestamp
  local latest_line = nil
  local latest_timestamp = nil

  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) then
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)%s*$')
      if timestamp then
        if not latest_timestamp or timestamp > latest_timestamp then
          latest_timestamp = timestamp
          latest_line = i
        end
      end
    end
  end

  if not latest_line then
    utils.echo('No sent shots to resend')
    return
  end

  -- Get shot info for the latest sent shot
  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, latest_line)
  if not shot_start then
    utils.echo('Could not find shot boundaries')
    return
  end

  local shot_info = { start_line = shot_start, end_line = shot_end, header_line = header_line }
  local shot_num = shots.parse_shot_header(lines[latest_line])

  -- Send the shot
  operations.send_specific_shots(pane_index, { shot_info }, bufnr, M.detect, M.send, M.messages)
  utils.echo('Resent shot ' .. shot_num .. ' to pane ' .. pane_index)
end

return M

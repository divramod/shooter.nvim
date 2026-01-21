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

return M

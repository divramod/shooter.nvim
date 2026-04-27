-- shooter.core.shot_actions public surface — re-exports the 16-fn API.
-- No logic; every function lives in a sibling sub-module.

local create = require('shooter.core.shot_actions.create')
local delete = require('shooter.core.shot_actions.delete')
local navigate = require('shooter.core.shot_actions.navigate')
local state = require('shooter.core.shot_actions.state')
local extract = require('shooter.core.shot_actions.extract')
local info = require('shooter.core.shot_actions.info')

local M = {}

-- create
M.create_new_shot = create.create_new_shot
M.create_new_shot_with_whisper = create.create_new_shot_with_whisper
M.create_shot_from_file = create.create_shot_from_file
M.create_shot_from_claude = create.create_shot_from_claude

-- delete
M.delete_last_shot = delete.delete_last_shot

-- navigate
M.goto_next_open_shot = navigate.goto_next_open_shot
M.goto_prev_open_shot = navigate.goto_prev_open_shot
M.goto_latest_sent_shot = navigate.goto_latest_sent_shot
M.goto_prev_sent_shot = navigate.goto_prev_sent_shot
M.goto_next_sent_shot = navigate.goto_next_sent_shot

-- state
M.toggle_shot_done = state.toggle_shot_done
M.undo_latest_sent_shot = state.undo_latest_sent_shot

-- extract
M.yank_shot = extract.yank_shot
M.extract_subtask = extract.extract_subtask
M.extract_line = extract.extract_line

-- info
M.file_stats = info.file_stats

return M

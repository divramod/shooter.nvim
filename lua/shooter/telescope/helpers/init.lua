-- Public surface of the telescope helpers area. Owns the `persistent_state`
-- singleton; sub-modules read/write through this table to keep a single
-- source of truth across module boundaries.
local M = {}

M.persistent_state = {}

local io_mod = require('shooter.telescope.helpers.io')
local shots_mod = require('shooter.telescope.helpers.shots')
local state_mod = require('shooter.telescope.helpers.state')
local files_mod = require('shooter.telescope.helpers.files')
local bullets_mod = require('shooter.telescope.helpers.bullets')

-- io.lua
M.get_file_mtime = io_mod.get_file_mtime
M.get_target_file = io_mod.get_target_file
M.read_lines = io_mod.read_lines

-- shots.lua
M.find_open_shots = shots_mod.find_open_shots
M.make_shot_entry = shots_mod.make_shot_entry
M.get_repo_prompt_files = shots_mod.get_repo_prompt_files
M.get_all_repo_shots = shots_mod.get_all_repo_shots

-- state.lua
M.clear_selection = state_mod.clear_selection
M.save_selection_state = state_mod.save_selection_state
M.restore_selection_state = state_mod.restore_selection_state

-- files.lua
M.get_prompt_files = files_mod.get_prompt_files
M.get_all_repos_prompt_files = files_mod.get_all_repos_prompt_files

-- bullets.lua
M.get_bullet_files = bullets_mod.get_bullet_files

return M

-- shooter.core.files public surface — re-exports the 27-fn API.
-- No logic; every function lives in a sibling sub-module.

local git = require('shooter.core.files.git')
local predicate = require('shooter.core.files.predicate')
local path_mod = require('shooter.core.files.path')
local io_mod = require('shooter.core.files.io')
local last_shotfile = require('shooter.core.files.last_shotfile')

local M = {}

-- git
M.get_git_root = git.get_git_root
M.get_cwd_git_root = git.get_cwd_git_root
M.get_file_git_root = git.get_file_git_root

-- predicate
M.is_metaplan = predicate.is_metaplan
M.is_plan_file = predicate.is_plan_file
M.is_plan_idea = predicate.is_plan_idea
M.is_in_prompts_folder = predicate.is_in_prompts_folder
M.is_shooter_file = predicate.is_shooter_file
M.is_last_trackable = predicate.is_last_trackable

-- path
M.get_current_file_path = path_mod.get_current_file_path
M.get_current_file_or_folder_path = path_mod.get_current_file_or_folder_path
M.get_prompts_dir = path_mod.get_prompts_dir
M.slugify_segment = path_mod.slugify_segment
M.slugify_path = path_mod.slugify_path
M.generate_filename = path_mod.generate_filename
M.title_from_path = path_mod.title_from_path
M.update_file_title = path_mod.update_file_title

-- io
M.open_shotfile = io_mod.open_shotfile
M.create_file = io_mod.create_file
M.get_file_title = io_mod.get_file_title
M.get_prompt_files = io_mod.get_prompt_files
M.ensure_theme_shotfiles = io_mod.ensure_theme_shotfiles

-- last_shotfile
M.track_last_shotfile = last_shotfile.track_last_shotfile
M.find_last_file = last_shotfile.find_last_file
M.get_last_edited_file = last_shotfile.get_last_edited_file

return M

-- Re-export surface for shooter.analytics.data (split during plan 0001
-- phase 004 T007 from the monolithic shooter/analytics/data.lua).

local parse = require('shooter.analytics.data.parse')
local repo = require('shooter.analytics.data.repo')
local sources = require('shooter.analytics.data.sources')
local stats = require('shooter.analytics.data.stats')

local M = {}

-- parse.lua
M.parse_executed_shot_header = parse.parse_executed_shot_header
M.get_shot_metrics = parse.get_shot_metrics
M.parse_shotfile = parse.parse_shotfile

-- repo.lua
M.get_git_remote_info = repo.get_git_remote_info
M.detect_project_from_path = repo.detect_project_from_path
M.repo_matches_filter = repo.repo_matches_filter

-- sources.lua
M.get_all_repo_paths = sources.get_all_repo_paths
M.get_all_shots = sources.get_all_shots

-- stats.lua
M.get_time_boundaries = stats.get_time_boundaries
M.calculate_stats = stats.calculate_stats
M.build_path_map = stats.build_path_map

return M

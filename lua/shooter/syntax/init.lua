-- Re-export surface for shooter.syntax (split during plan 0001 phase 004 T005).
-- Sub-modules:
--   highlights — define_highlights()
--   detect     — is_fence_delimiter / build_code_block_map / split_executed_header / is_prompts_file
--   apply      — apply_syntax / toggle_day_marker (extmark engine + day-marker state)
--   info       — show_shotfile_info / clear (one-shot per-buffer notification)
--   autocmds   — setup (autocommand wiring)
--   overrides  — reapply_all (ext_config color overrides + per-buf reapply)

local highlights = require('shooter.syntax.highlights')
local detect = require('shooter.syntax.detect')
local apply = require('shooter.syntax.apply')
local info = require('shooter.syntax.info')
local autocmds = require('shooter.syntax.autocmds')
local overrides = require('shooter.syntax.overrides')

local M = {}

-- Public API (unchanged from pre-split shooter/syntax.lua)
M.setup = autocmds.setup
M.reapply_all = overrides.reapply_all
M.toggle_day_marker = apply.toggle_day_marker

-- Helpers exposed for tests + downstream callers.
M.define_highlights = highlights.define_highlights
M.is_fence_delimiter = detect.is_fence_delimiter
M.build_code_block_map = detect.build_code_block_map
M.split_executed_header = detect.split_executed_header
M.is_prompts_file = detect.is_prompts_file
M.apply_syntax = apply.apply_syntax
M.show_shotfile_info = info.show_shotfile_info

return M

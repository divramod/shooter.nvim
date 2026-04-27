-- Re-export surface for shooter.tools.git_worktree (split during plan 0001
-- phase 004 T007 from the monolithic shooter/tools/git_worktree.lua).
--
-- Sub-modules:
--   repo    — get_repo_name, git_cmd, get_relative_file, WORKTREE_BASE
--   list    — get_worktrees, get_main_worktree, get_numbered_worktrees
--   state   — get_repo_wt_state_dir, ensure_gitignore, save_last/read_last
--   switch  — switch_to_worktree, switch_to(N), to_main, to_last
--   picker  — pick_worktree (Telescope)

local list = require('shooter.tools.git_worktree.list')
local switch = require('shooter.tools.git_worktree.switch')
local picker = require('shooter.tools.git_worktree.picker')

local M = {}

---@param number? number
function M.switch_to(number)
  switch.switch_to(number, picker.pick_worktree)
end

M.pick_worktree = picker.pick_worktree
M.to_last = switch.to_last
M.to_main = switch.to_main
M.get_main_worktree = list.get_main_worktree

return M

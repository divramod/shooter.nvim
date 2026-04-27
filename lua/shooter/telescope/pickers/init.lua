-- Public surface of the telescope pickers area. Re-exports the per-kind
-- picker entry points and the legacy `clear_selection` alias.
local M = {}

local helpers = require('shooter.telescope.helpers')
local file_mod = require('shooter.telescope.pickers.file')
local shot_mod = require('shooter.telescope.pickers.shot')
local bullet_mod = require('shooter.telescope.pickers.bullet')

-- Re-export clear_selection for external access (unchanged from pre-split).
M.clear_selection = helpers.clear_selection

-- File picker entry points
M.list_all_files = file_mod.list_all_files
M.list_all_repos_files = file_mod.list_all_repos_files

-- Shot picker entry points + mode singleton
-- shot_picker_mode lives on shot_mod; expose via metatable so external
-- writes (e.g. tests, future code) propagate to the canonical owner.
setmetatable(M, {
  __index = function(_, k)
    if k == 'shot_picker_mode' then return shot_mod.shot_picker_mode end
    return nil
  end,
  __newindex = function(t, k, v)
    if k == 'shot_picker_mode' then
      shot_mod.shot_picker_mode = v
      return
    end
    rawset(t, k, v)
  end,
})

M.list_open_shots = shot_mod.list_open_shots

-- Bullet picker entry points
M.list_bullets_current_file = bullet_mod.list_bullets_current_file
M.list_bullets_current_repo = bullet_mod.list_bullets_current_repo
M.list_bullets_all_repos = bullet_mod.list_bullets_all_repos

return M

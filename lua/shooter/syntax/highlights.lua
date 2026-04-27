-- Highlight group definitions (read from shooter.config defaults).
-- Pulled out of shooter/syntax.lua during plan 0001 phase 004 T005.

local M = {}

function M.define_highlights()
  local config = require('shooter.config')
  local open_shot = config.get('highlight.open_shot') or {}
  local open_shot_title = config.get('highlight.open_shot_title') or {}
  local done_shot_prefix = config.get('highlight.done_shot_prefix') or {}
  local done_shot_title = config.get('highlight.done_shot_title') or {}
  local done_shot_postfix = config.get('highlight.done_shot_postfix') or {}
  local day_marker_prefix = config.get('highlight.day_marker_prefix') or {}
  local day_marker_title = config.get('highlight.day_marker_title') or {}
  local day_marker_postfix = config.get('highlight.day_marker_postfix') or {}

  vim.api.nvim_set_hl(0, 'HalShooterOpenShot', {
    fg = open_shot.fg or '#000000',
    bg = open_shot.bg or '#ffb347',
    bold = open_shot.bold ~= false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterOpenShotTitle', {
    fg = open_shot_title.fg or '#333333',
    bg = open_shot_title.bg or '#ffe0a3',
    bold = open_shot_title.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterDoneShotPrefix', {
    fg = done_shot_prefix.fg or '#888888',
    bg = done_shot_prefix.bg or nil,
    bold = done_shot_prefix.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterDoneShotTitle', {
    fg = done_shot_title.fg or '#555555',
    bg = done_shot_title.bg or '#dcedc8',
    bold = done_shot_title.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterDoneShotPostfix', {
    fg = done_shot_postfix.fg or '#888888',
    bg = done_shot_postfix.bg or nil,
    bold = done_shot_postfix.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterDayMarkerPrefix', {
    fg = day_marker_prefix.fg or '#888888',
    bg = day_marker_prefix.bg or nil,
    bold = day_marker_prefix.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterDayMarkerTitle', {
    fg = day_marker_title.fg or '#555555',
    bg = day_marker_title.bg or '#f0e4d0',
    bold = day_marker_title.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterDayMarkerPostfix', {
    fg = day_marker_postfix.fg or '#888888',
    bg = day_marker_postfix.bg or nil,
    bold = day_marker_postfix.bold or false,
  })
  vim.api.nvim_set_hl(0, 'HalShooterMdLink', {
    fg = '#4fa3ff',
    underline = true,
  })
end

return M

-- Apply ext_config color overrides on top of the default highlight groups,
-- then reapply syntax to all loaded shotfile buffers.
-- Pulled out of shooter/syntax.lua during plan 0001 phase 004 T005.

local highlights = require('shooter.syntax.highlights')
local detect = require('shooter.syntax.detect')
local apply = require('shooter.syntax.apply')

local M = {}

function M.reapply_all()
  highlights.define_highlights()
  local eok, ext_config = pcall(require, 'shooter.core.ext_config')
  if eok then
    local config = require('shooter.config')
    local function apply_override(ext_key, hl_name, cfg_key, bg_nil_ok)
      local ext_bg = ext_config.get(ext_key .. '.color_bg')
      local ext_fg = ext_config.get(ext_key .. '.color_fg')
      if type(ext_bg) == 'string' or type(ext_fg) == 'string' then
        local defaults = config.get(cfg_key) or {}
        local bg = ext_bg or defaults.bg
        if bg_nil_ok and bg == '' then bg = nil end
        vim.api.nvim_set_hl(0, hl_name, {
          fg = ext_fg or defaults.fg or '#888888',
          bg = bg,
          bold = defaults.bold or false,
        })
      end
    end
    apply_override('file.open_shots', 'HalShooterOpenShot', 'highlight.open_shot')
    apply_override('file.open_shots_title', 'HalShooterOpenShotTitle', 'highlight.open_shot_title')
    apply_override('file.closed_shots_prefix', 'HalShooterDoneShotPrefix', 'highlight.done_shot_prefix', true)
    apply_override('file.closed_shots_title', 'HalShooterDoneShotTitle', 'highlight.done_shot_title')
    apply_override('file.closed_shots_postfix', 'HalShooterDoneShotPostfix', 'highlight.done_shot_postfix', true)
    apply_override('file.first_shot_of_the_day_prefix', 'HalShooterDayMarkerPrefix', 'highlight.day_marker_prefix', true)
    apply_override('file.first_shot_of_the_day_title', 'HalShooterDayMarkerTitle', 'highlight.day_marker_title')
    apply_override('file.first_shot_of_the_day_postfix', 'HalShooterDayMarkerPostfix', 'highlight.day_marker_postfix', true)
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if detect.is_prompts_file(filepath) then
        apply.apply_syntax(bufnr)
      end
    end
  end
end

return M

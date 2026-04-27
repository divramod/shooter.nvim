-- Autocommand wiring for shotfile syntax + ext_config / colorscheme reload.
-- Pulled out of shooter/syntax.lua during plan 0001 phase 004 T005.

local highlights = require('shooter.syntax.highlights')
local detect = require('shooter.syntax.detect')
local apply = require('shooter.syntax.apply')
local info = require('shooter.syntax.info')
local overrides = require('shooter.syntax.overrides')

local M = {}

function M.setup()
  highlights.define_highlights()

  local group = vim.api.nvim_create_augroup('HalShooterSyntax', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      if ft ~= 'markdown' then return end
      local files_mod = require('shooter.core.files')
      if detect.is_prompts_file(filepath) then
        files_mod.track_last_shotfile(filepath)
        apply.apply_syntax(ev.buf)
        info.show_shotfile_info(ev.buf)
        vim.bo[ev.buf].autoread = true
      elseif files_mod.is_metaplan(filepath) then
        files_mod.track_last_shotfile(filepath)
        vim.keymap.set('n', '<CR>', '<Cmd>HalShooterPlanOpenIdea<CR>', {
          buffer = ev.buf,
          silent = true,
          desc = 'Open plan idea.md (create if missing)',
        })
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      if ft == 'markdown' and detect.is_prompts_file(filepath) then
        apply.apply_syntax(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd('FileChangedShell', {
    group = group,
    pattern = '*.md',
    callback = function()
      vim.v.fcs_choice = 'reload'
    end,
  })

  vim.fn.timer_start(1000, function()
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      local filepath = vim.api.nvim_buf_get_name(buf)
      if filepath ~= '' and detect.is_prompts_file(filepath) then
        vim.cmd('silent! checktime')
      end
    end)
  end, { ['repeat'] = -1 })

  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(ev)
      info.clear(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      highlights.define_highlights()
    end,
  })

  -- Auto-reload + auto-fix shooter ext_config when its config.yaml is saved.
  local fixing_config = false
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      if fixing_config then return end
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      if filepath:match('hal/util/shooter/nvim/config%.yaml$') or filepath:match('%.hal/util/shooter/cfg/nvim/config%.yaml$') then
        local ext_config = require('shooter.core.ext_config')
        local is_global = filepath:match('hal/util/shooter/nvim/config%.yaml$') ~= nil
        local removed, added = ext_config.fix_config_buffer(ev.buf, is_global)
        if removed > 0 or added > 0 then
          fixing_config = true
          vim.cmd('noautocmd write')
          fixing_config = false
        end
        ext_config.reload()
        highlights.define_highlights()
        overrides.reapply_all()
      end
    end,
  })

  -- Auto-fix config.yaml on BufEnter (one-shot per buffer).
  local fixed_cfg_bufs = {}
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      if fixed_cfg_bufs[ev.buf] then return end
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local is_global = filepath:match('hal/util/shooter/nvim/config%.yaml$') ~= nil
      local is_local = filepath:match('%.hal/util/shooter/cfg/nvim/config%.yaml$') ~= nil
      if not is_global and not is_local then return end
      fixed_cfg_bufs[ev.buf] = true
      local eok, ext_config = pcall(require, 'shooter.core.ext_config')
      if not eok then return end
      ext_config.fix_config_buffer(ev.buf, is_global)
    end,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      fixed_cfg_bufs[ev.buf] = nil
    end,
  })
end

return M

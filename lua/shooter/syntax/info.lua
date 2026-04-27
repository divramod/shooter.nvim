-- One-shot per-buffer "shotfile info" notification.
-- Pulled out of shooter/syntax.lua during plan 0001 phase 004 T005.

local M = {}

local notified_bufs = {}

function M.show_shotfile_info(bufnr)
  if notified_bufs[bufnr] then return end
  notified_bufs[bufnr] = true

  local eok, ext_config = pcall(require, 'shooter.core.ext_config')
  if eok then
    local enabled = ext_config.get('file.stats_notification.enabled')
    if enabled == false then return end
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local shots = require('shooter.core.shots')
    local all = shots.find_all_shots(bufnr)
    local open = shots.find_open_shots(bufnr)

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local filename = vim.fn.fnamemodify(filepath, ':t:r')

    local git_root = vim.fn.systemlist({ 'git', 'rev-parse', '--show-toplevel' })
    local repo = (vim.v.shell_error == 0 and #git_root > 0)
      and vim.fn.fnamemodify(git_root[1], ':t') or ''

    local _ = string.format('%s/%s  %d/%d shots open', repo, filename, #open, #all)
  end)
end

function M.clear(bufnr)
  notified_bufs[bufnr] = nil
end

return M

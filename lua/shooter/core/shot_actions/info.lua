-- Shotfile stat helpers (no public side effect — pre-existing empty body).

local shots = require('shooter.core.shots')

local M = {}

-- Show stats for the current shotfile (total, open, closed shots).
function M.file_stats()
  local bufnr = 0
  local all = shots.find_all_shots(bufnr)
  local total = #all
  local closed = 0
  for _, shot in ipairs(all) do
    if shot.is_executed then closed = closed + 1 end
  end
  local open = total - closed

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local filename = bufname ~= '' and vim.fn.fnamemodify(bufname, ':t') or 'untitled'
end

return M

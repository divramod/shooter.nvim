-- File / mtime / current-target helpers used across the telescope helpers
-- sub-modules. Pure I/O; no telescope dependency.
local M = {}

function M.get_file_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if stat then
    return stat.mtime.sec
  end
  return 0
end

function M.get_target_file()
  local files_mod = require('shooter.core.files')
  local filepath = vim.fn.expand('%:p')

  if files_mod.is_in_prompts_folder(filepath) then
    return filepath, true
  end

  local last_file = files_mod.find_last_file()
  return last_file, false
end

function M.read_lines(target_file, is_current)
  if is_current then
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end
  local file = io.open(target_file, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  local lines = {}
  for line in content:gmatch('[^\n]*') do
    table.insert(lines, line)
  end
  return lines
end

return M

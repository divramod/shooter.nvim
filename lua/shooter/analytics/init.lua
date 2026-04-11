-- Analytics module for shooter.nvim
local M = {}
local data = require('shooter.analytics.data')
local report = require('shooter.analytics.report')

-- Re-export for backward compatibility
M.generate_report = report.generate_report

-- Extract filename from current line and open it
local function open_file_on_line(path_map)
  local line = vim.api.nvim_get_current_line()
  -- Match patterns: "filename.md", (filename.md), 1. filename.md
  for pattern in line:gmatch('[%w_%-%.]+%.md') do
    local full_path = path_map[pattern]
    if full_path and vim.fn.filereadable(full_path) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(full_path)); return
    end
  end
  -- Try to match any path-like string (e.g., /path/to/file.md)
  local path = line:match('([/%w_%-%.]+%.md)')
  if path and vim.fn.filereadable(path) == 1 then vim.cmd('edit ' .. vim.fn.fnameescape(path)); return end
end

-- Show analytics in a new buffer
function M.show(project_filter)
  local shots = data.get_all_shots(project_filter)
  local path_map = data.build_path_map(shots)
  local lines = M.generate_report(project_filter, shots)
  vim.cmd('enew')
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile, vim.bo.filetype = 'nofile', 'wipe', false, 'markdown'
  local title = project_filter and ('Shooter Analytics - ' .. project_filter) or 'Shooter Analytics (Global)'
  vim.api.nvim_buf_set_name(0, title); vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modifiable = false
  -- Add Enter keymap to open files
  vim.keymap.set('n', '<CR>', function() open_file_on_line(path_map) end, { buffer = true, desc = 'Open file on line' })
  vim.keymap.set('n', 'q', ':q<CR>', { buffer = true, silent = true, desc = 'Close' })
end

function M.show_global() M.show(nil) end

function M.show_project()
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  if not git_root then return end
  local user, repo = data.get_git_remote_info(git_root)
  if user and repo then
    M.show(user .. '/' .. repo)
  else
    M.show(vim.fn.fnamemodify(git_root, ':t'))
  end
end

return M

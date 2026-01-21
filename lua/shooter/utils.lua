-- Shared utility functions for shooter.nvim
-- Helper functions used across modules

local M = {}

-- Show message in command line (bottom bar) without requiring Enter press
function M.echo(msg)
  vim.schedule(function()
    vim.cmd('echon "' .. msg:gsub('"', '\\"') .. '"')
  end)
end

-- Show regular echo message (may require Enter)
function M.echo_regular(msg)
  vim.cmd('echo "' .. msg:gsub('"', '\\"') .. '"')
end

-- Expand path with ~ and environment variables
function M.expand_path(path)
  return vim.fn.expand(path)
end

-- Check if file exists
function M.file_exists(path)
  return vim.fn.filereadable(path) == 1
end

-- Check if directory exists
function M.dir_exists(path)
  return vim.fn.isdirectory(path) == 1
end

-- Ensure directory exists (create if missing)
function M.ensure_dir(path)
  vim.fn.mkdir(path, 'p')
end

-- Read file safely with error handling
function M.read_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil, string.format("Could not read file: %s", path)
  end
  local content = file:read('*a')
  file:close()
  return content, nil
end

-- Write file safely with error handling
function M.write_file(path, content)
  local file = io.open(path, 'w')
  if not file then
    return false, string.format("Could not write file: %s", path)
  end
  file:write(content)
  file:close()
  return true, nil
end

-- Get current working directory
function M.cwd()
  return vim.fn.getcwd()
end

-- Escape string for vim pattern matching
function M.escape_pattern(str)
  return vim.pesc(str)
end

-- Get timestamp in YYYY-MM-DD HH:MM:SS format
function M.get_timestamp()
  return os.date('%Y-%m-%d %H:%M:%S')
end

-- Get date in YYYY-MM-DD format
function M.get_date()
  return os.date('%Y-%m-%d')
end

-- Defer function execution
function M.defer(fn, delay_ms)
  vim.defer_fn(fn, delay_ms or 100)
end

-- Schedule function execution
function M.schedule(fn)
  vim.schedule(fn)
end

-- Trim whitespace from string
function M.trim(str)
  return str:match("^%s*(.-)%s*$")
end

-- Check if string starts with prefix
function M.starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

-- Check if string ends with suffix
function M.ends_with(str, suffix)
  return suffix == "" or str:sub(-#suffix) == suffix
end

-- Get file extension
function M.get_extension(path)
  return vim.fn.fnamemodify(path, ':e')
end

-- Get filename without extension
function M.get_basename(path)
  return vim.fn.fnamemodify(path, ':t:r')
end

-- Get directory from path
function M.get_dirname(path)
  return vim.fn.fnamemodify(path, ':h')
end

-- Get filename with extension
function M.get_filename(path)
  return vim.fn.fnamemodify(path, ':t')
end

-- Execute system command and return output
function M.system(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  local result = handle:read('*a')
  handle:close()
  return result
end

-- Execute system command (lines as array)
function M.systemlist(cmd)
  return vim.fn.systemlist(cmd)
end

-- Check if running in tmux
function M.in_tmux()
  return os.getenv('TMUX') ~= nil
end

-- Get buffer lines
function M.get_buf_lines(bufnr, start_line, end_line)
  return vim.api.nvim_buf_get_lines(bufnr, start_line or 0, end_line or -1, false)
end

-- Set buffer lines
function M.set_buf_lines(bufnr, start_line, end_line, lines)
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, lines)
end

-- Get current buffer number
function M.current_buf()
  return vim.api.nvim_get_current_buf()
end

-- Get line count in buffer
function M.buf_line_count(bufnr)
  bufnr = bufnr or 0
  return vim.api.nvim_buf_line_count(bufnr)
end

-- Get cursor position (row, col)
function M.get_cursor()
  return vim.api.nvim_win_get_cursor(0)
end

-- Set cursor position
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, {row, col or 0})
end

-- Get current line content
function M.get_current_line()
  return vim.api.nvim_get_current_line()
end

-- Escape filename for shell commands
function M.fnameescape(path)
  return vim.fn.fnameescape(path)
end

return M

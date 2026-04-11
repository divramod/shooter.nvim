-- hal.lua — Thin wrapper around `hal shooter` CLI commands
-- All shooter logic delegates to hal; this module handles CLI invocation,
-- JSON parsing, buffer save/reload, and error reporting.

local M = {}

--- Run a hal shooter command synchronously and return parsed JSON.
--- @param args table List of arguments after "hal shooter" (e.g. {'shot', 'list', '--file', path})
--- @return table {ok=bool, data=table|nil, error=string|nil}
function M.run(args)
  local cmd_parts = { 'hal', 'shooter' }
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, vim.fn.shellescape(arg))
  end
  -- Always request JSON output
  table.insert(cmd_parts, '--json')

  local cmd = table.concat(cmd_parts, ' ')
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    local err = output:gsub('%s+$', '')
    return { ok = false, data = nil, error = err }
  end

  -- Parse JSON
  local ok, data = pcall(vim.json.decode, output)
  if not ok then
    -- Non-JSON output (some commands output plain text even with --json)
    return { ok = true, data = nil, error = nil, raw = output:gsub('%s+$', '') }
  end

  return { ok = true, data = data, error = nil }
end

--- Run a hal shooter command without --json flag (for plain text output).
--- @param args table List of arguments after "hal shooter"
--- @return table {ok=bool, raw=string, error=string|nil}
function M.run_raw(args)
  local cmd_parts = { 'hal', 'shooter' }
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, vim.fn.shellescape(arg))
  end

  local cmd = table.concat(cmd_parts, ' ')
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    return { ok = false, raw = '', error = output:gsub('%s+$', '') }
  end

  return { ok = true, raw = output:gsub('%s+$', ''), error = nil }
end

--- Get the current buffer's file path.
--- @return string
function M.current_file()
  return vim.fn.expand('%:p')
end

--- Save the current buffer if it has unsaved changes.
function M.save_if_modified()
  if vim.bo.modified then
    vim.cmd('silent write')
  end
end

--- Reload the current buffer from disk after hal modified the file.
function M.reload()
  vim.cmd('edit!')
end

--- Convenience: save, run hal command that modifies the file, reload buffer.
--- @param args table hal shooter arguments
--- @return table result from M.run()
function M.modify(args)
  M.save_if_modified()
  local result = M.run(args)
  if result.ok then
    M.reload()
  else
  end
  return result
end

return M

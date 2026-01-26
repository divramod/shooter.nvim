-- Token counter tool for shooter.nvim
-- Uses ttok CLI to count tokens in files

local M = {}

-- Count tokens in a file using ttok
-- @param filepath string|nil File path to count tokens for (defaults to current buffer)
-- @return number|nil Token count, nil on error
-- @return string|nil Error message
function M.count_tokens(filepath)
  -- Get filepath from current buffer if not provided
  if not filepath then
    filepath = vim.fn.expand('%:p')
  end

  if filepath == '' then
    return nil, 'No file to count tokens for'
  end

  if vim.fn.filereadable(filepath) ~= 1 then
    return nil, 'File not readable: ' .. filepath
  end

  -- Check if ttok is installed
  if vim.fn.executable('ttok') ~= 1 then
    return nil, 'ttok is not installed. Install with: pip install ttok'
  end

  -- Run ttok on the file
  local cmd = string.format('ttok < %s 2>/dev/null', vim.fn.shellescape(filepath))
  local handle = io.popen(cmd)
  if not handle then
    return nil, 'Failed to run ttok command'
  end

  local result = handle:read('*a')
  handle:close()

  -- Parse the token count (ttok outputs just a number)
  -- Note: wrap gsub in parens to avoid passing replacement count to tonumber
  local cleaned = result:gsub('%s+', '')
  local token_count = tonumber(cleaned)
  if not token_count then
    return nil, 'Failed to parse ttok output: ' .. result
  end

  return token_count, nil
end

-- Display token count for current file
function M.show_token_count()
  local filepath = vim.fn.expand('%:p')
  local filename = vim.fn.expand('%:t')

  if filepath == '' then
    vim.notify('No file open', vim.log.levels.WARN)
    return
  end

  local count, err = M.count_tokens(filepath)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Format count with thousands separator
  local formatted = tostring(count):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
  vim.notify(string.format('%s: %s tokens', filename, formatted), vim.log.levels.INFO)
end

return M

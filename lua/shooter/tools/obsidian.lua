-- Obsidian integration for shooter.nvim
-- Opens current file in Obsidian if it's in a vault

local M = {}

-- Find the Obsidian vault root by looking for .obsidian directory
-- Returns vault_root, vault_name or nil, error
function M.find_vault(filepath)
  if not filepath or filepath == '' then
    return nil, 'No file path provided'
  end

  -- Start from the file's directory
  local dir = vim.fn.fnamemodify(filepath, ':h')

  -- Walk up the directory tree looking for .obsidian
  while dir and dir ~= '/' and dir ~= '' do
    local obsidian_dir = dir .. '/.obsidian'
    if vim.fn.isdirectory(obsidian_dir) == 1 then
      -- Found it! dir is the vault root
      local vault_name = vim.fn.fnamemodify(dir, ':t')
      return dir, vault_name
    end
    -- Go up one level
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then
      break -- Reached root
    end
    dir = parent
  end

  return nil, 'Not in an Obsidian vault (no .obsidian directory found)'
end

-- Get the relative path from vault root
function M.get_relative_path(filepath, vault_root)
  -- Remove vault root prefix and leading slash
  local relative = filepath:gsub('^' .. vim.pesc(vault_root) .. '/?', '')
  return relative
end

-- URL encode a string for obsidian:// URI
function M.url_encode(str)
  if not str then return '' end
  -- Replace special characters with percent-encoded versions
  str = str:gsub('([^%w%-%.%_%~%/])', function(c)
    return string.format('%%%02X', string.byte(c))
  end)
  return str
end

-- Open the current file in Obsidian
function M.open_in_obsidian()
  -- Get current file path
  local filepath = vim.fn.expand('%:p')
  if filepath == '' then
    vim.notify('No file open', vim.log.levels.WARN)
    return false
  end

  -- Find the vault
  local vault_root, vault_name = M.find_vault(filepath)
  if not vault_root then
    vim.notify(vault_name, vim.log.levels.WARN) -- vault_name contains error message
    return false
  end

  -- Get relative path within vault
  local relative_path = M.get_relative_path(filepath, vault_root)

  -- Build obsidian:// URL
  local url = string.format(
    'obsidian://open?vault=%s&file=%s',
    M.url_encode(vault_name),
    M.url_encode(relative_path)
  )

  -- Open with system command
  local open_cmd
  if vim.fn.has('mac') == 1 then
    open_cmd = 'open'
  elseif vim.fn.has('unix') == 1 then
    open_cmd = 'xdg-open'
  else
    vim.notify('Unsupported platform', vim.log.levels.ERROR)
    return false
  end

  local cmd = string.format('%s "%s"', open_cmd, url)
  local result = os.execute(cmd)

  if result == 0 then
    vim.notify(string.format('Opened in Obsidian: %s', relative_path), vim.log.levels.INFO)
    return true
  else
    vim.notify('Failed to open Obsidian', vim.log.levels.ERROR)
    return false
  end
end

return M

-- Health checks for optional CLI tools
-- Separated from main health.lua to keep files under 200 lines

local M = {}

-- Check if hal CLI is available (optional - for image picking)
function M.check_hal_cli()
  if vim.fn.executable('hal') ~= 1 then
    vim.health.info('hal CLI not found', {
      'Optional: Install hal CLI for image picking with <space>I (ShooterImages)',
      'https://github.com/divramod/hal',
    })
    return false
  end
  local handle = io.popen('hal --version 2>/dev/null')
  local version = handle and handle:read('*l') or 'unknown'
  if handle then handle:close() end
  vim.health.ok(string.format('hal CLI: %s', version))
  return true
end

-- Check if python is available (optional - for ttok token counting)
function M.check_python()
  -- Check for python3 first, then python
  local python_cmd = nil
  if vim.fn.executable('python3') == 1 then
    python_cmd = 'python3'
  elseif vim.fn.executable('python') == 1 then
    python_cmd = 'python'
  end

  if not python_cmd then
    vim.health.info('python not found', {
      'Optional: Install Python for token counting with ttok',
      'macOS: brew install python | Ubuntu: sudo apt-get install python3',
    })
    return false
  end

  local handle = io.popen(python_cmd .. ' --version 2>&1')
  local version = handle and handle:read('*l') or 'unknown'
  if handle then handle:close() end
  vim.health.ok(string.format('%s: %s', python_cmd, version))
  return true
end

-- Check if ttok is available (optional - for token counting)
function M.check_ttok()
  if vim.fn.executable('ttok') ~= 1 then
    vim.health.info('ttok not found', {
      'Optional: Install ttok for token counting with <space>ttc',
      'Install with: pip install ttok',
      'https://github.com/simonw/ttok',
    })
    return false
  end

  -- Test ttok works by counting a simple string
  local handle = io.popen('echo "test" | ttok 2>/dev/null')
  local result = handle and handle:read('*a') or ''
  if handle then handle:close() end

  if result:gsub('%s+', '') == '' then
    vim.health.warn('ttok installed but not working', {
      'Try reinstalling: pip install --upgrade ttok',
    })
    return false
  end

  vim.health.ok('ttok: installed and working')
  return true
end

return M

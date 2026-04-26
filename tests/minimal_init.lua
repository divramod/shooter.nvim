-- Minimal init for test environment
-- Sets up a clean Neovim environment for running plenary tests + luacov coverage.

-- Set up basic runtime paths
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

-- Package root for installing test dependencies
local package_root = '/tmp/nvim/site/pack'
local plenary_path = package_root .. '/packer/start/plenary.nvim'
local luacov_path = package_root .. '/packer/start/luacov'

-- Install plenary if not present
if vim.fn.isdirectory(plenary_path) == 0 then
  print('Installing plenary.nvim for tests...')
  vim.fn.system({
    'git', 'clone', '--depth=1',
    'https://github.com/nvim-lua/plenary.nvim',
    plenary_path,
  })
end

-- Install luacov if not present (for coverage reporting)
if vim.fn.isdirectory(luacov_path) == 0 then
  print('Installing luacov for coverage...')
  vim.fn.system({
    'git', 'clone', '--depth=1',
    'https://github.com/lunarmodules/luacov',
    luacov_path,
  })
end

-- Expose luacov on package.path (its modules live under src/)
package.path = luacov_path .. '/src/?.lua;'
            .. luacov_path .. '/src/?/init.lua;'
            .. package.path

-- Start luacov BEFORE shooter modules load so they are instrumented.
-- pcall: tests still run if coverage tooling is unavailable.
local cov_ok, cov_err = pcall(require, 'luacov')
if cov_ok then
  -- Neovim doesn't run Lua atexit hooks on :qa, so wire shutdown explicitly.
  local runner_ok, runner = pcall(require, 'luacov.runner')
  if runner_ok then
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function() pcall(runner.shutdown) end,
    })
  end
else
  print('warning: luacov failed to load; coverage will not be recorded: ' .. tostring(cov_err))
end

-- Add plenary to runtime
vim.cmd([[runtime! plugin/plenary.vim]])

-- Add shooter.nvim to runtime (current directory)
vim.cmd([[set rtp+=.]])

-- Set up minimal options for testing
vim.opt.swapfile = false
vim.opt.hidden = true

print('Test environment initialized')

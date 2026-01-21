-- Minimal init for test environment
-- This file sets up a clean Neovim environment for running plenary tests

-- Set up basic runtime paths
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

-- Package root for installing test dependencies
local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/plenary.nvim'

-- Install plenary if not present
if vim.fn.isdirectory(install_path) == 0 then
  print('Installing plenary.nvim for tests...')
  vim.fn.system({
    'git', 'clone', '--depth=1',
    'https://github.com/nvim-lua/plenary.nvim',
    install_path
  })
end

-- Add plenary to runtime
vim.cmd([[runtime! plugin/plenary.vim]])

-- Add shooter.nvim to runtime (current directory)
vim.cmd([[set rtp+=.]])

-- Set up minimal options for testing
vim.opt.swapfile = false
vim.opt.hidden = true

print('Test environment initialized')

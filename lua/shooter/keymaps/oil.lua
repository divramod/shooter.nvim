-- Oil buffer keymaps for shooter.nvim
-- Binds shotfile namespace commands to work in Oil

local M = {}

local config = require('shooter.config')

-- Get the keymap prefix
local function get_prefix()
  return config.get('keymaps.prefix') or ' '
end

-- Context-aware shotfile operations for Oil
-- These operate on the file under cursor in Oil
local function get_oil_file()
  local ok, oil = pcall(require, 'oil')
  if not ok then return nil end
  local entry = oil.get_cursor_entry()
  if not entry then return nil end
  local dir = oil.get_current_dir()
  if dir and entry.name then
    return dir .. entry.name
  end
  return nil
end

-- Move file under cursor to folder
local function move_oil_file_to(folder)
  local filepath = get_oil_file()
  if not filepath then
    vim.notify('No file under cursor', vim.log.levels.WARN)
    return
  end
  local movement = require('shooter.core.movement')
  if movement.move_file_path(filepath, folder) then
    -- Refresh Oil
    vim.cmd('edit')
  end
end

-- Rename file under cursor
local function rename_oil_file()
  local filepath = get_oil_file()
  if not filepath then
    vim.notify('No file under cursor', vim.log.levels.WARN)
    return
  end
  -- Open the file first, then rename
  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
  require('shooter.core.rename').rename_current_file()
end

-- Delete file under cursor
local function delete_oil_file()
  local filepath = get_oil_file()
  if not filepath then
    vim.notify('No file under cursor', vim.log.levels.WARN)
    return
  end
  local filename = vim.fn.fnamemodify(filepath, ':t')
  vim.ui.input({ prompt = 'Delete ' .. filename .. '? (y/n): ' }, function(confirm)
    if confirm == 'y' then
      vim.fn.delete(filepath)
      vim.notify('Deleted: ' .. filename, vim.log.levels.INFO)
      -- Refresh Oil
      vim.cmd('edit')
    end
  end)
end

-- Setup Oil buffer keymaps
function M.setup_oil_keymaps(bufnr)
  local prefix = get_prefix()
  local opts = { buffer = bufnr, noremap = true, silent = true }

  local function map(lhs, rhs, desc)
    vim.keymap.set('n', prefix .. lhs, rhs, vim.tbl_extend('force', opts, { desc = desc }))
  end

  -- Shotfile move commands (fm prefix) - operate on file under cursor
  map('fma', function() move_oil_file_to('archive') end, 'Move to archive')
  map('fmb', function() move_oil_file_to('backlog') end, 'Move to backlog')
  map('fmd', function() move_oil_file_to('done') end, 'Move to done')
  map('fmp', function() move_oil_file_to('') end, 'Move to prompts')
  map('fmr', function() move_oil_file_to('reqs') end, 'Move to reqs')
  map('fmt', function() move_oil_file_to('test') end, 'Move to test')
  map('fmw', function() move_oil_file_to('wait') end, 'Move to wait')
  map('fmg', function() move_oil_file_to('__git_root__') end, 'Move to git root')
  map('fmm', function()
    local filepath = get_oil_file()
    if filepath then
      vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
      vim.cmd('ShooterShotfileMovePicker')
    end
  end, 'Fuzzy folder picker')

  -- Rename (fr)
  map('fr', rename_oil_file, 'Rename file')

  -- Delete (fd)
  map('fd', delete_oil_file, 'Delete file')

  -- Open file (just use Enter in Oil, but provide consistency)
  map('fn', ':ShooterShotfileNew<cr>', 'New shotfile')

  -- Other shotfile commands
  map('fl', ':ShooterShotfileLast<cr>', 'Last file')
  map('fp', ':ShooterShotfilePicker<cr>', 'Shotfile picker')
  map('fi', ':ShooterShotfileHistory<cr>', 'History')
end

-- Setup autocmd to apply Oil keymaps
function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'oil',
    callback = function(ev)
      M.setup_oil_keymaps(ev.buf)
    end,
    group = vim.api.nvim_create_augroup('ShooterOilKeymaps', { clear = true }),
  })
end

return M

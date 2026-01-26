-- Clipboard image handling for shooter.nvim
-- Save clipboard images to .shooter.nvim/images/ and insert path

local M = {}

local utils = require('shooter.utils')

-- Get plugin root path dynamically
local function get_plugin_root()
  local info = debug.getinfo(1, 'S')
  local path = info.source:sub(2) -- remove leading @
  return path:match('(.*/shooter%.nvim)') or vim.fn.fnamemodify(path, ':h:h:h:h')
end

-- Get path to the clipboard-image script
function M.get_script_path()
  return get_plugin_root() .. '/scripts/shooter-clipboard-image'
end

-- Default directory for saved clipboard images
M.default_save_dir = vim.fn.expand('~/.clipboard-images')

-- Check if clipboard contains an image
function M.has_image()
  local script = M.get_script_path()
  vim.fn.system(script .. ' check')
  return vim.v.shell_error == 0
end

-- Save clipboard image and return the path
function M.save_image(save_dir)
  save_dir = save_dir or M.default_save_dir
  local script = M.get_script_path()
  local cmd = script .. ' save ' .. vim.fn.shellescape(save_dir)
  local result = vim.fn.system(cmd)
  if vim.v.shell_error == 0 then
    return vim.fn.trim(result)
  end
  return nil
end

-- Get git repository root directory
function M.get_git_root()
  local result = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end
  return nil
end

-- Ensure .shooter.nvim/images folder has .gitkeep and .gitignore
function M.ensure_gitfiles(images_dir)
  local gitkeep = images_dir .. '/.gitkeep'
  local gitignore = images_dir .. '/.gitignore'

  if vim.fn.filereadable(gitkeep) == 0 then
    local f = io.open(gitkeep, 'w')
    if f then
      f:write('# This file ensures the images directory is tracked by git\n')
      f:write('# Images in this folder are gitignored to keep the repo clean\n')
      f:close()
    end
  end

  if vim.fn.filereadable(gitignore) == 0 then
    local f = io.open(gitignore, 'w')
    if f then
      f:write('# Ignore all files in this directory\n*\n\n')
      f:write('# Except these files\n!.gitkeep\n!.gitignore\n')
      f:close()
    end
  end
end

-- Get save directory based on current buffer context
-- Saves to <reporoot>/.shooter.nvim/images/ if in a git repo
function M.get_save_dir()
  local git_root = M.get_git_root()
  if git_root then
    local images_dir = git_root .. '/.shooter.nvim/images'
    vim.fn.mkdir(images_dir, 'p')
    M.ensure_gitfiles(images_dir)
    return images_dir
  end
  return M.default_save_dir
end

-- Paste clipboard image path at cursor position (insert mode)
function M.paste_image_insert()
  if not M.has_image() then
    return false
  end
  local save_dir = M.get_save_dir()
  local path = M.save_image(save_dir)
  if path then
    local col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local before = string.sub(line, 1, col - 1)
    local after = string.sub(line, col)
    vim.api.nvim_set_current_line(before .. path .. after)
    vim.fn.cursor(vim.fn.line('.'), col + #path)
    utils.notify('Pasted image: ' .. path, vim.log.levels.INFO)
    return true
  end
  utils.notify('Failed to save clipboard image', vim.log.levels.ERROR)
  return false
end

-- Paste clipboard image path on next line (normal mode)
function M.paste_image_normal()
  if not M.has_image() then
    utils.notify('No image in clipboard', vim.log.levels.WARN)
    return false
  end
  local save_dir = M.get_save_dir()
  local path = M.save_image(save_dir)
  if path then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, { path })
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
    utils.notify('Pasted image: ' .. path, vim.log.levels.INFO)
    return true
  end
  utils.notify('Failed to save clipboard image', vim.log.levels.ERROR)
  return false
end

-- Smart paste: handles both text and images (for normal mode 'p')
function M.smart_paste_after()
  if M.has_image() then
    M.paste_image_normal()
  else
    vim.cmd('normal! p')
  end
end

-- Smart paste: handles both text and images (for normal mode 'P')
function M.smart_paste_before()
  if M.has_image() then
    local save_dir = M.get_save_dir()
    local path = M.save_image(save_dir)
    if path then
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { path })
      utils.notify('Pasted image: ' .. path, vim.log.levels.INFO)
    else
      utils.notify('Failed to save clipboard image', vim.log.levels.ERROR)
    end
  else
    vim.cmd('normal! P')
  end
end

-- Check command - notify if clipboard has image
function M.check()
  if M.has_image() then
    utils.notify('Clipboard contains an image', vim.log.levels.INFO)
  else
    utils.notify('Clipboard does not contain an image', vim.log.levels.INFO)
  end
end

-- Open images directory in Oil
function M.open_images_dir()
  local images_dir = M.get_save_dir()
  vim.cmd('Oil ' .. images_dir)
end

return M

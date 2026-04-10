-- Move file to folder via Telescope picker
-- Fuzzy search folders like Obsidian

local M = {}

local utils = require('shooter.utils')
local files = require('shooter.core.files')

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

-- Get shotfile folders (system folders + domains)
local function get_shotfile_folders()
  local git_worktree = require('shooter.tools.git_worktree')
  local git_root = git_worktree.get_main_worktree() or files.get_git_root() or utils.cwd()
  local shotfiles_dir = git_root .. '/.hal/shooter/shotfiles'

  local folders = {}
  -- Root (prompts)
  table.insert(folders, { display = '(root)', path = shotfiles_dir })

  if not utils.dir_exists(shotfiles_dir) then return folders, git_root end

  local entries = vim.fn.readdir(shotfiles_dir)
  for _, entry in ipairs(entries) do
    local full_path = shotfiles_dir .. '/' .. entry
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(folders, { display = entry, path = full_path })
    end
  end

  table.sort(folders, function(a, b) return a.display < b.display end)
  return folders, git_root
end

-- Move file to selected folder
local function move_file_to_folder(file_path, target_folder_path, was_in_oil, cursor_line)
  local filename = utils.get_filename(file_path)
  local target_path = target_folder_path .. '/' .. filename

  -- Check if source file exists
  if not utils.file_exists(file_path) then
    vim.notify('File not found: ' .. file_path, vim.log.levels.ERROR)
    return false
  end

  -- Ensure target directory exists
  utils.ensure_dir(target_folder_path)

  -- Check if target already exists
  if utils.file_exists(target_path) then
    vim.notify('Target already exists: ' .. target_path, vim.log.levels.ERROR)
    return false
  end

  -- Move the file
  local success = os.rename(file_path, target_path)
  if success then
    vim.notify('Moved to ' .. target_folder_path)

    if was_in_oil then
      -- Refresh Oil buffer
      local ok, oil = pcall(require, 'oil')
      if ok then
        local current_dir = oil.get_current_dir()
        if current_dir then
          vim.cmd('edit ' .. vim.fn.fnameescape(current_dir))
        end
      end
    else
      -- Open file at new location
      vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
    end
    return true
  else
    vim.notify('Failed to move file', vim.log.levels.ERROR)
    return false
  end
end

-- Open folder picker to move current file
function M.open_picker()
  local file_path = files.get_current_file_path()
  local was_in_oil = vim.bo.filetype == 'oil'
  local cursor_line = was_in_oil and vim.api.nvim_win_get_cursor(0)[1] or nil

  if not file_path or file_path == '' then
    vim.notify('No file selected', vim.log.levels.WARN)
    return
  end

  local folders = get_shotfile_folders()

  if #folders == 0 then
    vim.notify('No folders found', vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = 'Move to Folder',
    layout_strategy = 'vertical',
    layout_config = { width = 0.6, height = 0.6 },
    finder = finders.new_table({
      results = folders,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      -- Close on C-c in both modes
      map('i', '<C-c>', function() actions.close(prompt_bufnr) end)
      map('n', '<C-c>', function() actions.close(prompt_bufnr) end)
      map('n', 'q', function() actions.close(prompt_bufnr) end)

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          move_file_to_folder(file_path, entry.value.path, was_in_oil, cursor_line)
        end
      end)
      return true
    end,
  }):find()
end

return M

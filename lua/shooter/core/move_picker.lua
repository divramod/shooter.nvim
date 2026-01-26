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

-- Get all folders from git root, respecting .gitignore
local function get_project_folders()
  local git_root = files.get_git_root()
  if not git_root then
    git_root = utils.cwd()
  end

  -- Use git ls-files to get all tracked files, then extract unique directories
  -- This respects .gitignore automatically
  local cmd = string.format(
    'cd "%s" && git ls-files --full-name 2>/dev/null | xargs -I{} dirname {} | sort -u',
    git_root
  )
  local result = vim.fn.systemlist(cmd)

  -- Also add directories that exist but might not have tracked files yet
  local cmd2 = string.format(
    'cd "%s" && find . -type d -not -path "*/\\.git/*" 2>/dev/null | sed "s|^\\./||" | sort -u',
    git_root
  )
  local find_result = vim.fn.systemlist(cmd2)

  -- Merge and dedupe
  local seen = {}
  local folders = {}

  -- Add root
  table.insert(folders, { display = '.', path = git_root })
  seen['.'] = true

  for _, dir in ipairs(result) do
    if dir ~= '' and dir ~= '.' and not seen[dir] then
      seen[dir] = true
      table.insert(folders, { display = dir, path = git_root .. '/' .. dir })
    end
  end

  for _, dir in ipairs(find_result) do
    if dir ~= '' and dir ~= '.' and not seen[dir] then
      -- Check if this folder should be ignored (simple .gitignore check)
      local check_cmd = string.format('cd "%s" && git check-ignore -q "%s" 2>/dev/null', git_root, dir)
      vim.fn.system(check_cmd)
      if vim.v.shell_error ~= 0 then -- Not ignored
        seen[dir] = true
        table.insert(folders, { display = dir, path = git_root .. '/' .. dir })
      end
    end
  end

  -- Sort by path
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

  local folders, git_root = get_project_folders()

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

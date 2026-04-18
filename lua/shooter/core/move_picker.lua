-- Move file to folder via Telescope picker
-- Fuzzy search folders like Obsidian, with free-form path input as an alternative.

local M = {}

local utils = require('shooter.utils')
local files = require('shooter.core.files')

-- Collect every subfolder under shotfiles_dir, recursively, as a sorted list.
-- The first entry is always `(root)` pointing at shotfiles_dir itself. Display
-- paths are relative to shotfiles_dir (e.g. "apps/next/domain"); full path is
-- absolute so picker callbacks can move files into the exact directory.
function M.collect_shotfile_folders(shotfiles_dir)
  local folders = { { display = '(root)', path = shotfiles_dir } }

  if not utils.dir_exists(shotfiles_dir) then
    return folders
  end

  local function walk(dir, rel_prefix)
    local entries = vim.fn.readdir(dir)
    for _, entry in ipairs(entries) do
      local full_path = dir .. '/' .. entry
      if vim.fn.isdirectory(full_path) == 1 then
        local display = rel_prefix == '' and entry or (rel_prefix .. '/' .. entry)
        table.insert(folders, { display = display, path = full_path })
        walk(full_path, display)
      end
    end
  end

  walk(shotfiles_dir, '')
  table.sort(folders, function(a, b) return a.display < b.display end)
  return folders
end

-- Get shotfile folders and the resolved shotfiles root for the current repo.
local function get_shotfile_folders()
  local git_worktree = require('shooter.tools.git_worktree')
  local git_root = git_worktree.get_main_worktree() or files.get_git_root() or utils.cwd()
  local shotfiles_dir = git_root .. '/.hal/util/shooter/shotfiles'
  return M.collect_shotfile_folders(shotfiles_dir), shotfiles_dir
end

-- Parse a free-form telescope prompt into (target_dir, target_basename).
--
--   "apps/next/domain"  -> (shotfiles_dir/apps/next, "domain.md")
--   "apps/next/"        -> (shotfiles_dir/apps/next, nil)   (nil = keep source name)
--   "/"                 -> (shotfiles_dir,             nil)
--   "foo.md"            -> (shotfiles_dir,             "foo.md") — only if the caller
--                         routed us here (i.e. the prompt contained a slash or was a
--                         rename); callers should only invoke this when the prompt
--                         contains a slash so fuzzy filtering still works for plain
--                         folder names.
--
-- Returns nil for empty prompts.
function M.parse_move_prompt(prompt, shotfiles_dir)
  if not prompt or prompt == '' then return nil end

  -- Strip leading slashes so absolute-looking inputs stay within shotfiles_dir.
  local path = prompt:gsub('^/+', '')
  if path == '' then
    return shotfiles_dir, nil
  end

  local trailing = path:sub(-1) == '/'
  if trailing then
    local dir = path:gsub('/+$', '')
    if dir == '' then
      return shotfiles_dir, nil
    end
    local dir_slug = files.slugify_path(dir)
    return shotfiles_dir .. (dir_slug ~= '' and ('/' .. dir_slug) or ''), nil
  end

  local dir, name = path:match('^(.-)/([^/]+)$')
  if dir and dir ~= '' then
    local base = name:gsub('%.md$', '')
    local dir_slug = files.slugify_path(dir)
    local name_slug = files.slugify_segment(base)
    return shotfiles_dir .. (dir_slug ~= '' and ('/' .. dir_slug) or ''),
      name_slug .. '.md'
  end
  -- Prompt had no interior slash (e.g. just "foo"); only reached here if caller
  -- routed us here explicitly. Treat as "rename at shotfiles root".
  local base = path:gsub('%.md$', '')
  return shotfiles_dir, files.slugify_segment(base) .. '.md'
end

-- Refresh Oil buffer in place after a filesystem change.
local function refresh_oil_buffer()
  local ok, oil = pcall(require, 'oil')
  if not ok then return end
  local current_dir = oil.get_current_dir()
  if current_dir then
    vim.cmd('edit ' .. vim.fn.fnameescape(current_dir))
  end
end

-- Walk up from the given directory and remove any now-empty subfolder of
-- .hal/util/shooter/shotfiles. Stops at the first non-empty directory, the
-- shotfiles root itself, or any directory outside a shotfiles tree.
local function cleanup_empty_source_dirs(source_dir)
  while source_dir and source_dir ~= '' do
    -- Only walk inside a .hal/util/shooter/shotfiles/<sub>/... subtree.
    -- The trailing slash in the literal match excludes the shotfiles root itself.
    if not source_dir:find('/.hal/util/shooter/shotfiles/', 1, true) then
      return
    end
    local entries = vim.fn.readdir(source_dir)
    if #entries > 0 then return end
    if vim.fn.delete(source_dir, 'd') ~= 0 then return end
    source_dir = vim.fn.fnamemodify(source_dir, ':h')
  end
end

-- Move a shotfile to an absolute target path.
-- Creates the parent directory if needed, refuses to overwrite, updates the H1
-- title to match the new path, and reopens the file / oil buffer appropriately.
-- Returns ok_bool.
function M.move_file_to_path(file_path, target_path, was_in_oil)
  if not file_path or file_path == '' then return false end
  if not utils.file_exists(file_path) then
    utils.echo('Source file not found')
    return false
  end
  if file_path == target_path then
    return false
  end

  local target_dir = vim.fn.fnamemodify(target_path, ':h')
  utils.ensure_dir(target_dir)

  if utils.file_exists(target_path) then
    utils.echo('Target already exists: ' .. vim.fn.fnamemodify(target_path, ':t'))
    return false
  end

  local source_dir = vim.fn.fnamemodify(file_path, ':h')

  local success = os.rename(file_path, target_path)
  if not success then
    utils.echo('Failed to move file')
    return false
  end

  files.update_file_title(target_path, files.title_from_path(target_path))
  cleanup_empty_source_dirs(source_dir)

  if was_in_oil then
    refresh_oil_buffer()
  else
    vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
  end

  local shown = target_path:gsub('^' .. vim.pesc(vim.fn.getcwd() .. '/'), '')
  utils.echo('Moved to ' .. shown)
  return true
end

-- Move file into a target folder, keeping its current filename.
local function move_file_to_folder(file_path, target_folder_path, was_in_oil)
  local filename = utils.get_filename(file_path)
  return M.move_file_to_path(file_path, target_folder_path .. '/' .. filename, was_in_oil)
end

-- Open folder picker to move current file.
function M.open_picker()
  local file_path = files.get_current_file_path()
  local was_in_oil = vim.bo.filetype == 'oil'

  if not file_path or file_path == '' then
    return
  end

  local folders, shotfiles_dir = get_shotfile_folders()

  if #folders == 0 then
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Move to Folder (type path/name or path/ to rename or keep)',
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
      require('shooter.keymaps.picker').setup_nav_keymaps(map)
      -- Close on C-c in both modes
      map('i', '<C-c>', function() actions.close(prompt_bufnr) end)
      map('n', '<C-c>', function() actions.close(prompt_bufnr) end)
      map('n', 'q', function() actions.close(prompt_bufnr) end)

      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local prompt = picker and picker:_get_prompt() or ''

        -- If the prompt contains a slash, the user is entering an explicit path
        -- instead of selecting one of the fuzzy-filtered folders. Route through
        -- parse_move_prompt so trailing-slash (keep name) and non-trailing-slash
        -- (rename) both work.
        if prompt ~= '' and prompt:find('/', 1, true) then
          actions.close(prompt_bufnr)
          local target_dir, target_basename = M.parse_move_prompt(prompt, shotfiles_dir)
          if not target_dir then return end
          local filename = target_basename or utils.get_filename(file_path)
          M.move_file_to_path(file_path, target_dir .. '/' .. filename, was_in_oil)
          return
        end

        -- Otherwise fall back to existing folder-selection behaviour.
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          move_file_to_folder(file_path, entry.value.path, was_in_oil)
        end
      end)
      return true
    end,
  }):find()
end

return M

-- File movement operations for shooter.nvim
-- Move files between folders (archive, backlog, done, etc.)

local utils = require('shooter.utils')
local config = require('shooter.config')
local files = require('shooter.core.files')

local M = {}

-- Helper: Position cursor on filename in Oil buffer
local function oil_position_on_file(target_dir, filename)
  vim.cmd('Oil ' .. target_dir)
  utils.defer(function()
    local lines = utils.get_buf_lines(0, 0, -1)
    for i, line in ipairs(lines) do
      if line:match(utils.escape_pattern(filename)) then
        utils.set_cursor(i, 0)
        break
      end
    end
  end, 100)
end

-- Helper: In Oil, focus next file after current position, or first folder if none
local function oil_focus_next_or_first_folder(current_line)
  utils.defer(function()
    local ok, oil = pcall(require, 'oil')
    if not ok then return end

    local lines = utils.get_buf_lines(0, 0, -1)
    local total_lines = #lines

    -- Clamp current_line to valid range
    if current_line > total_lines then current_line = total_lines end
    if current_line < 1 then current_line = 1 end

    -- Try to find a file at or after current position
    for i = current_line, total_lines do
      utils.set_cursor(i, 0)
      local entry = oil.get_cursor_entry()
      if entry and entry.type == 'file' then
        return
      end
    end

    -- No file found after, try from beginning
    for i = 1, current_line - 1 do
      utils.set_cursor(i, 0)
      local entry = oil.get_cursor_entry()
      if entry and entry.type == 'file' then
        return
      end
    end

    -- No files at all, look for first folder
    for i = 1, total_lines do
      utils.set_cursor(i, 0)
      local entry = oil.get_cursor_entry()
      if entry and entry.type == 'directory' then
        return
      end
    end

    -- Fallback: stay at line 1
    utils.set_cursor(1, 0)
  end, 200)
end

-- Move file to target subfolder
-- target_folder: empty string = prompts root, otherwise subfolder name
-- open_in_oil: if true, opens Oil at target dir with cursor on moved file
function M.move_to_folder(target_folder, open_in_oil)
  local file_path = files.get_current_file_path()
  local was_in_oil = vim.bo.filetype == 'oil'
  local cursor_line = was_in_oil and utils.get_cursor()[1] or nil

  if not file_path or file_path == '' then
    utils.echo('No file selected')
    return
  end

  -- Only allow moving files in the prompts folder
  if not files.is_in_prompts_folder(file_path) then
    utils.echo('File is not in prompts folder')
    return
  end

  -- Get filename and build target path
  local filename = utils.get_filename(file_path)
  local cwd = utils.cwd()
  local target_dir

  if target_folder == '' then
    target_dir = cwd .. '/' .. config.get('paths.prompts_root')
  else
    target_dir = cwd .. '/' .. config.get('paths.prompts_root') .. '/' .. target_folder
  end

  local target_path = target_dir .. '/' .. filename

  -- Check if source file exists
  if not utils.file_exists(file_path) then
    utils.echo('File not found: ' .. file_path)
    return
  end

  -- Ensure target directory exists
  utils.ensure_dir(target_dir)

  -- Check if target already exists
  if utils.file_exists(target_path) then
    utils.echo('Target already exists: ' .. target_path)
    return
  end

  -- Move the file
  local success = os.rename(file_path, target_path)
  if success then
    local display_folder = target_folder == '' and 'prompts' or target_folder
    utils.echo('Moved to ' .. display_folder .. '/' .. filename)

    if was_in_oil and not open_in_oil then
      -- In Oil: refresh Oil buffer and focus next file or first folder
      local ok, oil = pcall(require, 'oil')
      if ok then
        local current_dir = oil.get_current_dir()
        if current_dir then
          vim.cmd('edit ' .. utils.fnameescape(current_dir))
        end
      end
      oil_focus_next_or_first_folder(cursor_line)
    elseif open_in_oil then
      -- Explicitly requested to open in Oil
      oil_position_on_file(target_dir, filename)
    else
      -- Editing a file: stay in editing mode, open file at new location
      vim.cmd('edit ' .. utils.fnameescape(target_path))
    end
  else
    utils.echo('Failed to move file')
  end
end

-- Convenience functions for common folders
function M.move_to_archive()
  M.move_to_folder('archive')
end

function M.move_to_backlog()
  M.move_to_folder('backlog')
end

function M.move_to_done()
  M.move_to_folder('done')
end

function M.move_to_reqs()
  M.move_to_folder('reqs')
end

function M.move_to_test()
  M.move_to_folder('test')
end

function M.move_to_wait()
  M.move_to_folder('wait')
end

function M.move_to_prompts()
  M.move_to_folder('', false)
end

-- Move file or folder to git root
function M.move_to_git_root()
  local path, entry_type = files.get_current_file_or_folder_path()
  local was_in_oil = vim.bo.filetype == 'oil'
  local cursor_line = was_in_oil and utils.get_cursor()[1] or nil

  if not path or path == '' then
    utils.echo('No file or folder selected')
    return
  end

  local git_root = files.get_git_root()
  if not git_root then
    utils.echo('Not in a git repository')
    return
  end

  local name = utils.get_filename(path)
  local target_path = git_root .. '/' .. name

  -- Check if source exists
  if not utils.dir_exists(path) and not utils.file_exists(path) then
    utils.echo('Source not found: ' .. path)
    return
  end

  -- Check if target already exists
  if utils.dir_exists(target_path) or utils.file_exists(target_path) then
    utils.echo('Target already exists: ' .. target_path)
    return
  end

  -- Move the file or folder
  local success = os.rename(path, target_path)
  if success then
    utils.echo('Moved to git root: ' .. name)

    if was_in_oil then
      local ok, oil = pcall(require, 'oil')
      if ok then
        local current_dir = oil.get_current_dir()
        if current_dir then
          vim.cmd('edit ' .. utils.fnameescape(current_dir))
        end
      end
      oil_focus_next_or_first_folder(cursor_line)
    else
      -- If in file being moved, open at new location
      local current_buf_path = vim.fn.expand('%:p')
      if current_buf_path == path then
        vim.cmd('edit ' .. target_path)
      end
    end
  else
    utils.echo('Failed to move to git root')
  end
end

return M

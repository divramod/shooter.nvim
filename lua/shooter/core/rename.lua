-- File rename module for shooter.nvim
-- Flow: prompt for title -> generate filename slug -> update title heading -> rename file

local files = require('shooter.core.files')

local M = {}

-- Get the current file path (supports normal buffer and Oil)
local function get_current_filepath()
  local filepath = files.get_current_file_path()
  return (filepath and filepath ~= '') and filepath or nil
end

-- Extract directory and filename from path
local function split_path(filepath)
  return vim.fn.fnamemodify(filepath, ':h'), vim.fn.fnamemodify(filepath, ':t')
end

-- Perform the actual rename operation
-- @param old_path: Full path to current file
-- @param new_filename: New filename (just the name, not path)
-- @return success, error_message
function M.perform_rename(old_path, new_filename)
  if not old_path or not new_filename or new_filename == '' then
    return false, 'Invalid parameters'
  end

  local dir, old_filename = split_path(old_path)

  -- Don't rename if same name
  if old_filename == new_filename then
    return false, 'Name unchanged'
  end

  local new_path = dir .. '/' .. new_filename

  -- Check if target exists
  if vim.fn.filereadable(new_path) == 1 then
    return false, 'File already exists: ' .. new_filename
  end

  -- Rename the prompt file
  local ok = os.rename(old_path, new_path)
  if not ok then
    return false, 'Failed to rename file'
  end

  return true, nil, {
    new_path = new_path,
  }
end

-- Main entry point: prompt user for new title, then rename file accordingly
function M.rename_current_file()
  local filepath = get_current_filepath()
  if not filepath then return end

  -- Get the buffer number for this file (if it's open)
  local bufnr = vim.fn.bufnr(filepath)

  -- Use filename (without ext) as the editable name
  local current_name = vim.fn.fnamemodify(filepath, ':t:r')

  -- Prompt user to edit the name
  vim.ui.input({
    prompt = 'New title: ',
    default = current_name,
  }, function(new_name)
    if not new_name or new_name == '' then
      return
    end
    if new_name == current_name then
      return
    end

    -- Generate new filename from name
    local new_filename = files.generate_filename(new_name)
    local dir = split_path(filepath)
    local new_path = dir .. '/' .. new_filename

    -- Check if target exists
    if vim.fn.filereadable(new_path) == 1 then
      return
    end

    -- CRITICAL: Save and close the buffer before modifying file on disk
    -- This prevents content loss when Neovim's buffer state conflicts with disk state
    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
      -- Save any unsaved changes first
      if vim.bo[bufnr].modified then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd('silent! write')
        end)
      end
      -- Wipe the buffer so we can safely rename the underlying file
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    -- Update title to match new path (includes domain prefix)
    local new_title = files.title_from_path(new_path)
    files.update_file_title(filepath, new_title)

    -- Perform file rename
    local success, _, info = M.perform_rename(filepath, new_filename)
    if not success then
      return
    end

    -- Open the renamed file fresh
    vim.cmd('edit ' .. vim.fn.fnameescape(info.new_path))
  end)
end

return M

-- File rename module for shooter.nvim
-- Flow: prompt for title -> generate filename slug -> update title heading -> rename file

local utils = require('shooter.utils')
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

-- Extract title from file's first # heading
local function extract_title(filepath)
  local file = io.open(filepath, 'r')
  if not file then return nil end
  for line in file:lines() do
    local title = line:match('^#%s+(.+)$')
    if title then file:close(); return title end
  end
  file:close()
  return nil
end

-- Update the first # heading in file with new title
local function update_title_in_file(filepath, new_title)
  local content = utils.read_file(filepath)
  if not content then return false end
  -- Use [^\n]+ to match only until end of line (not across newlines)
  local updated = content:gsub('^(#%s+)[^\n]+', '%1' .. new_title, 1)
  if updated == content then
    -- No heading found, try after first line (might have frontmatter)
    updated = content:gsub('\n(#%s+)[^\n]+', '\n%1' .. new_title, 1)
  end
  if updated ~= content then
    utils.write_file(filepath, updated)
    return true
  end
  return false
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
  if not filepath then utils.notify('No file selected', vim.log.levels.WARN); return end

  -- Get the buffer number for this file (if it's open)
  local bufnr = vim.fn.bufnr(filepath)

  -- Extract current title from file
  local current_title = extract_title(filepath)
  if not current_title then
    -- Fallback to filename without extension if no title heading
    current_title = vim.fn.fnamemodify(filepath, ':t:r')
  end

  -- Prompt user to edit the title
  vim.ui.input({
    prompt = 'New title: ',
    default = current_title,
  }, function(new_title)
    if not new_title or new_title == '' then
      utils.notify('Rename cancelled', vim.log.levels.INFO); return
    end
    if new_title == current_title then
      utils.notify('Title unchanged', vim.log.levels.INFO); return
    end

    -- Generate new filename from title
    local new_filename = files.generate_filename(new_title)
    local dir = split_path(filepath)
    local new_path = dir .. '/' .. new_filename

    -- Check if target exists
    if vim.fn.filereadable(new_path) == 1 then
      utils.notify('File already exists: ' .. new_filename, vim.log.levels.ERROR); return
    end

    -- CRITICAL: Save and close the buffer before modifying file on disk
    -- This prevents content loss when Neovim's buffer state conflicts with disk state
    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
      -- Save any unsaved changes first
      if vim.bo[bufnr].modified then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd('write')
        end)
      end
      -- Wipe the buffer so we can safely rename the underlying file
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    -- Update title heading in file (on disk, buffer is now closed)
    local title_updated = update_title_in_file(filepath, new_title)

    -- Perform file rename
    local success, err, info = M.perform_rename(filepath, new_filename)
    if not success then
      utils.notify('Rename failed: ' .. (err or 'unknown error'), vim.log.levels.ERROR); return
    end

    -- Open the renamed file fresh
    vim.cmd('edit ' .. vim.fn.fnameescape(info.new_path))

    -- Report results
    local msg = 'Renamed to "' .. new_title .. '"'
    if title_updated then msg = msg .. ' (title updated)' end
    utils.notify(msg, vim.log.levels.INFO)
  end)
end

return M

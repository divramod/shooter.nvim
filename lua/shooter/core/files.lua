-- File operations for shooter.nvim
-- Creating, listing, and managing shooter files

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Helper: Get git root directory
function M.get_git_root()
  local result = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end
  return nil
end

-- Helper: Get file path (works in normal buffer and Oil)
function M.get_current_file_path()
  local filetype = vim.bo.filetype

  if filetype == 'oil' then
    -- In Oil: get the file under cursor
    local ok, oil = pcall(require, 'oil')
    if ok then
      local entry = oil.get_cursor_entry()
      if entry and entry.type == 'file' then
        local dir = oil.get_current_dir()
        return dir .. entry.name
      end
    end
    return nil
  else
    -- Normal buffer: get current file
    return vim.fn.expand('%:p')
  end
end

-- Helper: Get file or folder path (works in normal buffer and Oil)
function M.get_current_file_or_folder_path()
  local filetype = vim.bo.filetype

  if filetype == 'oil' then
    -- In Oil: get the file or folder under cursor
    local ok, oil = pcall(require, 'oil')
    if ok then
      local entry = oil.get_cursor_entry()
      if entry then
        local dir = oil.get_current_dir()
        return dir .. entry.name, entry.type
      end
    end
    return nil, nil
  else
    -- Normal buffer: get current file
    return vim.fn.expand('%:p'), 'file'
  end
end

-- Helper: Get prompts directory path (project-aware)
-- project = nil means root level, string means specific project
function M.get_prompts_dir(project)
  local project_mod = require('shooter.core.project')
  return project_mod.get_prompts_dir(project)
end

-- Helper: Check if path is in prompts folder (checks both root and project paths)
function M.is_in_prompts_folder(path)
  if not path then return false end
  -- Check root prompts path
  local root_prompts = utils.cwd() .. '/' .. config.get('paths.prompts_root')
  if path:find(root_prompts, 1, true) then
    return true
  end
  -- Check project prompts paths
  local git_root = M.get_git_root()
  if git_root and path:find(git_root .. '/projects/.+/plans/prompts') then
    return true
  end
  return false
end

-- Helper: Check if current file is a next-action/shooter file
function M.is_shooter_file(filepath)
  filepath = filepath or vim.fn.expand('%:p')
  return M.is_in_prompts_folder(filepath)
end

-- Get shooter files from directory (returns display paths without plans/prompts prefix)
-- project = nil means root level, string means specific project
function M.get_prompt_files(project)
  local prompts_dir = M.get_prompts_dir(project)
  local files = vim.fn.globpath(prompts_dir, '**/*.md', false, true)
  local results = {}

  for _, file in ipairs(files) do
    -- Store both display path (without plans/prompts/) and full path
    local display = file:gsub('^' .. utils.escape_pattern(prompts_dir) .. '/', '')
    table.insert(results, { display = display, path = file, project = project })
  end

  return results
end

-- Get file title (first # heading in the file)
function M.get_file_title(bufnr)
  bufnr = bufnr or 0
  local lines = utils.get_buf_lines(bufnr, 0, 50)

  for _, line in ipairs(lines) do
    local title = line:match('^#%s+(.+)$')
    if title then
      return title
    end
  end

  -- Fallback to filename without extension
  return utils.get_basename(vim.fn.expand('%:p'))
end

-- Generate filename from title (slug.md)
function M.generate_filename(title)
  -- Slugify title
  local slug = title:lower()
  slug = slug:gsub('%s+', '-')
  slug = slug:gsub('[^%w%-]', '')
  slug = slug:gsub('%-+', '-')
  slug = slug:gsub('^%-', ''):gsub('%-$', '')

  return string.format('%s.md', slug)
end

-- Create new shooter file (project-aware)
-- project = nil means root level, string means specific project
function M.create_file(title, folder, initial_content, project)
  folder = folder or ''
  local project_mod = require('shooter.core.project')
  local base_path = project_mod.get_prompts_root(project)

  if folder ~= '' then
    base_path = base_path .. '/' .. folder
  end

  local filename = M.generate_filename(title)
  local git_root = M.get_git_root() or utils.cwd()
  local full_path = git_root .. '/' .. base_path .. '/' .. filename

  -- Ensure directory exists
  local dir = utils.get_dirname(full_path)
  utils.ensure_dir(dir)

  -- Build file content
  local file_content

  if initial_content and initial_content ~= '' then
    -- Check if content contains shot pattern
    local has_shot_pattern = initial_content:match(config.get('patterns.shot_header'))

    if has_shot_pattern then
      file_content = string.format('# %s\n\n\n%s\n', title, initial_content)
    else
      file_content = string.format('# %s\n\n## shot 1\n%s\n', title, initial_content)
    end
  else
    file_content = string.format('# %s\n\n## shot 1\n\n', title)
  end

  -- Write the file
  local success, err = utils.write_file(full_path, file_content)
  if not success then
    utils.echo('Failed to create file: ' .. err)
    return nil
  end

  return full_path, filename
end

-- Find last edited shooter file (project-aware)
-- project = nil means root level, string means specific project
function M.find_last_file(project)
  local prompts_dir = M.get_prompts_dir(project)

  if not utils.dir_exists(prompts_dir) then
    return nil
  end

  local cmd = string.format('find "%s" -name "*.md" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1', prompts_dir)
  local result = utils.system(cmd)

  if not result or result == '' then
    return nil
  end

  return result:gsub('%s+$', '')  -- Trim trailing whitespace
end

-- Alias for find_last_file (used by commands.lua)
function M.get_last_edited_file(project)
  return M.find_last_file(project)
end

return M

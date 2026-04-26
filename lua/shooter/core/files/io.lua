-- File I/O for shooter: open shotfile, create new file, read titles,
-- enumerate prompt files, ensure theme shotfiles exist.

local utils = require('shooter.utils')
local config = require('shooter.config')
local git = require('shooter.core.files.git')
local path_mod = require('shooter.core.files.path')

local M = {}

function M.open_shotfile(filepath)
  if not filepath or filepath == '' then return end
  local target_root = git.get_file_git_root(filepath)
  if target_root and target_root ~= vim.fn.getcwd() then
    vim.cmd('cd ' .. vim.fn.fnameescape(target_root))
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
end

function M.get_prompt_files(project)
  local prompts_dir = path_mod.get_prompts_dir(project)
  local results = {}
  if not prompts_dir then return results end
  local files = vim.fn.globpath(prompts_dir, '**/*.md', false, true)
  for _, file in ipairs(files) do
    local display = file:gsub('^' .. utils.escape_pattern(prompts_dir) .. '/', '')
    table.insert(results, { display = display, path = file, project = project })
  end
  return results
end

function M.get_file_title(bufnr)
  bufnr = bufnr or 0
  local lines = utils.get_buf_lines(bufnr, 0, 50)
  for _, line in ipairs(lines) do
    local title = line:match('^#%s+(.+)$')
    if title then return title end
  end
  return utils.get_basename(vim.fn.expand('%:p'))
end

-- Create new shooter file. project = nil means root level; string targets a sub-project.
function M.create_file(title, folder, initial_content, project)
  folder = folder or ''

  local title_dir, title_name = title:match('^(.+)/([^/]+)$')
  if title_dir and title_name then
    folder = (folder ~= '') and (folder .. '/' .. title_dir) or title_dir
    title = title_name
  end

  local project_mod = require('shooter.core.project')
  local base_path = project_mod.get_prompts_root(project)

  if folder ~= '' then
    base_path = base_path .. '/' .. folder
  end

  local filename = path_mod.generate_filename(title)
  local git_root = git.get_git_root() or utils.cwd()
  local full_path = git_root .. '/' .. base_path .. '/' .. filename

  local dir = utils.get_dirname(full_path)
  utils.ensure_dir(dir)

  local slug = filename:gsub('%.md$', '')
  local path_title = (folder ~= '') and (folder .. '/' .. slug) or slug

  local file_content
  if initial_content and initial_content ~= '' then
    local has_shot_pattern = initial_content:match(config.get('patterns.shot_header'))
    if has_shot_pattern then
      file_content = string.format('# %s\n\n\n%s\n', path_title, initial_content)
    else
      file_content = string.format('# %s\n\n## shot 1\n%s\n', path_title, initial_content)
    end
  else
    file_content = string.format('# %s\n\n## shot 1\n\n', path_title)
  end

  local success, err = utils.write_file(full_path, file_content)
  if not success then
    utils.echo('Failed to create file: ' .. err)
    return nil
  end
  return full_path, filename
end

-- Ensure theme shotfiles exist based on .hal/util/shooter/themes.json.
function M.ensure_theme_shotfiles()
  local git_root = git.get_git_root()
  if not git_root then return 0 end

  local themes_path = git_root .. '/.hal/util/shooter/themes.json'
  local f = io.open(themes_path, 'r')
  if not f then return 0 end

  local content = f:read('*a')
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data or not data.themes then return 0 end

  local created = 0
  for _, theme in ipairs(data.themes) do
    if theme.shotfile and theme.title then
      local shotfile_path = git_root .. '/' .. theme.shotfile
      if vim.fn.filereadable(shotfile_path) ~= 1 then
        local dir = vim.fn.fnamemodify(shotfile_path, ':h')
        vim.fn.mkdir(dir, 'p')
        local sf = io.open(shotfile_path, 'w')
        if sf then
          sf:write('# ' .. theme.title .. '\n')
          sf:close()
          created = created + 1
        end
      end
    end
  end

  return created
end

return M

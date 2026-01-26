-- Project detection and path resolution for shooter.nvim
-- Handles mono-repos with projects/ folder structure

local M = {}

-- Check if projects/ folder exists at git root
-- Returns: boolean
function M.has_projects()
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  if not git_root then
    return false
  end
  local projects_dir = git_root .. '/projects'
  return vim.fn.isdirectory(projects_dir) == 1
end

-- Get the projects directory path
-- Returns: absolute path to projects/ or nil
function M.get_projects_dir()
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  if not git_root then
    return nil
  end
  local projects_dir = git_root .. '/projects'
  if vim.fn.isdirectory(projects_dir) == 1 then
    return projects_dir
  end
  return nil
end

-- Get list of available projects
-- Returns: array of { name = string, path = string }
function M.list_projects()
  local projects_dir = M.get_projects_dir()
  if not projects_dir then return {} end

  local config = require('shooter.config')
  local exclude = config.get('projects.exclude_folders') or {}
  local exclude_set = {}
  for _, folder in ipairs(exclude) do exclude_set[folder] = true end

  local projects = {}
  local handle = io.popen('ls -1 "' .. projects_dir .. '" 2>/dev/null')
  if handle then
    for name in handle:lines() do
      local path = projects_dir .. '/' .. name
      if vim.fn.isdirectory(path) == 1 and not exclude_set[name] then
        table.insert(projects, { name = name, path = path })
      end
    end
    handle:close()
  end
  table.sort(projects, function(a, b) return a.name < b.name end)
  return projects
end

-- Detect current project from a file path
-- Returns: project name or nil if not in a project
function M.detect_from_path(filepath)
  if not filepath or filepath == '' then
    return nil
  end

  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  if not git_root then
    return nil
  end

  -- Check if path contains /projects/<name>/
  local pattern = vim.pesc(git_root) .. '/projects/([^/]+)/'
  local project = filepath:match(pattern)
  return project
end

-- Detect project from current working directory
-- Returns: project name or nil if cwd is not inside a project
function M.detect_from_cwd()
  local cwd = vim.fn.getcwd()
  return M.detect_from_path(cwd .. '/')
end

-- Get prompts directory for a specific project (or root)
-- project = nil means root level (plans/prompts)
-- Returns: absolute path to prompts dir
function M.get_prompts_dir(project)
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  local base = git_root or vim.fn.getcwd()

  if project and project ~= '' then
    return base .. '/projects/' .. project .. '/plans/prompts'
  else
    return base .. '/plans/prompts'
  end
end

-- Get prompts root relative path for a project
-- Returns: "projects/<project>/plans/prompts" or "plans/prompts"
function M.get_prompts_root(project)
  if project and project ~= '' then
    return 'projects/' .. project .. '/plans/prompts'
  else
    return 'plans/prompts'
  end
end

-- Show telescope picker to select project
-- callback(project_name) called with selection (nil for root/cancel)
function M.pick_project(callback, opts)
  opts = opts or {}
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local projects = M.list_projects()
  if #projects == 0 then
    vim.notify('No projects found in projects/ folder', vim.log.levels.WARN)
    callback(nil)
    return
  end

  -- Add "(root)" option at the beginning if requested
  local entries = {}
  if opts.include_root then
    table.insert(entries, { name = '(root)', path = nil, is_root = true })
  end
  for _, p in ipairs(projects) do
    table.insert(entries, p)
  end

  pickers.new({}, {
    prompt_title = opts.title or 'Select Project',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          local project = selection.value.is_root and nil or selection.value.name
          callback(project)
        else
          callback(nil)
        end
      end)
      return true
    end,
  }):find()
end

return M

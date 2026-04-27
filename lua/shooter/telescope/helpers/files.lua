-- Prompt-file walkers (single-repo and all-repos). Pure Lua + filesystem
-- globbing; no telescope dependency.
local M = {}

local utils = require('shooter.utils')
local io_mod = require('shooter.telescope.helpers.io')

-- opts table supports:
--   folder_filter: 'a', 'b', 'd', 'r', 'w', 'p' or full folder name
--   project: single project name (legacy support)
--   projects: array of project names to include
--   sort_by_mtime: boolean to sort by modification time
--   include_all_projects: boolean to include all projects
function M.get_prompt_files(folder_filter_or_opts, project)
  local files_mod = require('shooter.core.files')
  local project_mod = require('shooter.core.project')
  local _ = project_mod  -- preserve original require side-effect ordering

  local opts = {}
  if type(folder_filter_or_opts) == 'table' then
    opts = folder_filter_or_opts
  else
    opts.folder_filter = folder_filter_or_opts
    opts.project = project
  end

  local results = {}
  local seen = {}

  local function add_from_prompts_dir(prompts_dir, display_prefix, proj_name)
    local search_dir = prompts_dir
    local glob_pattern
    if opts.folder_filter and opts.folder_filter ~= '' then
      search_dir = search_dir .. '/' .. opts.folder_filter
      glob_pattern = '**/*.md'
    else
      glob_pattern = '**/*.md'
    end
    if not utils.dir_exists(search_dir) then return end
    local file_list = vim.fn.globpath(search_dir, glob_pattern, false, true)
    local base = prompts_dir .. '/'
    for _, file in ipairs(file_list) do
      if not seen[file] then
        seen[file] = true
        local display = display_prefix .. file:gsub('^' .. vim.pesc(base), '')
        table.insert(results, { display = display, path = file, project = proj_name })
      end
    end
  end

  -- Add per-plan idea.md / spec.md / masterplan.md files alongside metaplan.md.
  local function add_plan_files(git_root)
    local plans_dir = git_root .. '/docs/plans'
    if vim.fn.isdirectory(plans_dir) ~= 1 then return end
    local mp = plans_dir .. '/metaplan.md'
    if vim.fn.filereadable(mp) == 1 and not seen[mp] then
      seen[mp] = true
      table.insert(results, { display = 'docs/plans/metaplan.md',
        path = mp, project = nil })
    end
    for _, name in ipairs(vim.fn.readdir(plans_dir)) do
      if name:match('^%d%d%d%d%-[%l%d][%w%-]*$')
          and vim.fn.isdirectory(plans_dir .. '/' .. name) == 1 then
        for _, kind in ipairs({ 'idea', 'spec', 'masterplan' }) do
          local p = plans_dir .. '/' .. name .. '/' .. kind .. '.md'
          if vim.fn.filereadable(p) == 1 and not seen[p] then
            seen[p] = true
            table.insert(results, {
              display = 'docs/plans/' .. name .. '/' .. kind .. '.md',
              path = p,
              project = nil,
            })
          end
        end
      end
    end
  end

  if opts.include_all_projects then
    -- Always resolve from main worktree so shotfiles are visible from any worktree.
    local git_worktree = require('shooter.tools.git_worktree')
    local git_root = git_worktree.get_main_worktree() or files_mod.get_git_root() or utils.cwd()
    add_from_prompts_dir(git_root .. '/docs/shotfiles', '', nil)
    add_plan_files(git_root)
    local projects_dir = git_root .. '/projects'
    if vim.fn.isdirectory(projects_dir) == 1 then
      local config = require('shooter.config')
      local exclude = config.get('projects.exclude_folders') or {}
      local exclude_set = {}
      for _, folder in ipairs(exclude) do exclude_set[folder] = true end
      local entries = vim.fn.readdir(projects_dir)
      for _, name in ipairs(entries) do
        local path = projects_dir .. '/' .. name
        if vim.fn.isdirectory(path) == 1 and not exclude_set[name] then
          add_from_prompts_dir(path .. '/docs/shotfiles', name .. '/', name)
        end
      end
    end
  elseif opts.projects and #opts.projects > 0 then
    for _, proj_name in ipairs(opts.projects) do
      local prompts_dir = files_mod.get_prompts_dir(proj_name)
      local prefix = proj_name and proj_name ~= '' and (proj_name .. '/') or ''
      add_from_prompts_dir(prompts_dir, prefix, proj_name)
    end
  else
    local prompts_dir = files_mod.get_prompts_dir(opts.project)
    add_from_prompts_dir(prompts_dir, '', opts.project)
  end

  if opts.sort_by_mtime then
    table.sort(results, function(a, b)
      return io_mod.get_file_mtime(a.path) > io_mod.get_file_mtime(b.path)
    end)
  end

  return results
end

-- opts table supports:
--   folder_filter: folder to filter by
--   sort_by_mtime: boolean to sort by modification time
function M.get_all_repos_prompt_files(folder_filter_or_opts)
  local config = require('shooter.config')
  local results = {}
  local seen = {}

  local opts = {}
  if type(folder_filter_or_opts) == 'table' then
    opts = folder_filter_or_opts
  else
    opts.folder_filter = folder_filter_or_opts
  end

  local function add_prompts_dir(prompts_dir, display_prefix, repo_name)
    local search_dir = prompts_dir
    local glob_pattern

    if opts.folder_filter and opts.folder_filter ~= '' then
      search_dir = search_dir .. '/' .. opts.folder_filter
      glob_pattern = '**/*.md'
    else
      glob_pattern = '*.md'
    end

    if utils.dir_exists(search_dir) then
      local files = vim.fn.globpath(search_dir, glob_pattern, false, true)
      for _, file in ipairs(files) do
        if not seen[file] then
          seen[file] = true
          local rel = file:gsub('^' .. vim.pesc(prompts_dir) .. '/', '')
          table.insert(results, { display = display_prefix .. rel, path = file, repo = repo_name })
        end
      end
    end
  end

  local function add_repo_files(repo_path, repo_name)
    add_prompts_dir(repo_path .. '/docs/shotfiles', repo_name .. '/', repo_name)

    local projects_dir = repo_path .. '/projects'
    if utils.dir_exists(projects_dir) then
      if vim.fn.isdirectory(projects_dir) == 1 then
        for _, project in ipairs(vim.fn.readdir(projects_dir)) do
          local project_prompts = projects_dir .. '/' .. project .. '/docs/shotfiles'
          add_prompts_dir(project_prompts, repo_name .. '/' .. project .. '/', repo_name)
        end
      end
    end
  end

  for _, path in ipairs(config.get('repos.direct_paths') or {}) do
    local expanded = utils.expand_path(path)
    if utils.dir_exists(expanded .. '/.git') then
      add_repo_files(expanded, vim.fn.fnamemodify(expanded, ':t'))
    end
  end

  for _, dir in ipairs(config.get('repos.search_dirs') or {}) do
    local expanded = utils.expand_path(dir)
    if utils.dir_exists(expanded) then
      if vim.fn.isdirectory(expanded) == 1 then
        for _, name in ipairs(vim.fn.readdir(expanded)) do
          local subdir = expanded .. '/' .. name
          if utils.dir_exists(subdir .. '/.git') then
            add_repo_files(subdir, vim.fn.fnamemodify(subdir, ':t'))
          end
        end
      end
    end
  end

  if opts.sort_by_mtime then
    table.sort(results, function(a, b)
      return io_mod.get_file_mtime(a.path) > io_mod.get_file_mtime(b.path)
    end)
  end

  return results
end

return M

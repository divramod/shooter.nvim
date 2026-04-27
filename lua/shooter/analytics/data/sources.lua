-- Repo + shot discovery. Walks configured search dirs + project subdirs.
-- Pulled out of shooter/analytics/data.lua during plan 0001 phase 004 T007.
-- T008 down-payment: replaced io.popen('ls -d ...') with vim.fn.readdir + isdirectory.
-- replaced io.popen('find ... | wc -l') for shot enumeration with vim.fs.find.

local utils = require('shooter.utils')
local config = require('shooter.config')
local parse = require('shooter.analytics.data.parse')
local repo_mod = require('shooter.analytics.data.repo')

local M = {}

-- Get all configured repos from shooter config.
function M.get_all_repo_paths()
  local repos = {}
  local seen = {}

  -- Add current repo via table-form git
  local git_root_out = vim.fn.system({ 'git', 'rev-parse', '--show-toplevel' })
  if git_root_out and git_root_out ~= '' and vim.v.shell_error == 0 then
    local git_root = utils.trim(git_root_out)
    if not seen[git_root] then
      seen[git_root] = true
      table.insert(repos, git_root)
    end
  end

  -- Direct paths from config
  local direct_paths = config.get('repos.direct_paths') or {}
  for _, path in ipairs(direct_paths) do
    local expanded = utils.expand_path(path)
    if not seen[expanded] and utils.dir_exists(expanded .. '/.git') then
      seen[expanded] = true
      table.insert(repos, expanded)
    end
  end

  -- Search dirs — enumerate via vim.fn.readdir (no shell)
  local search_dirs = config.get('repos.search_dirs') or {}
  for _, dir in ipairs(search_dirs) do
    local expanded_dir = utils.expand_path(dir)
    if utils.dir_exists(expanded_dir) then
      local entries = vim.fn.readdir(expanded_dir)
      if type(entries) == 'table' then
        for _, name in ipairs(entries) do
          local subdir = expanded_dir .. '/' .. name
          if vim.fn.isdirectory(subdir) == 1
              and not seen[subdir]
              and utils.dir_exists(subdir .. '/.git') then
            seen[subdir] = true
            table.insert(repos, subdir)
          end
        end
      end
    end
  end

  return repos
end

local function find_md_files(root)
  if not root or vim.fn.isdirectory(root) ~= 1 then return {} end
  return vim.fs.find(function(name) return name:match('%.md$') end,
    { path = root, type = 'file', limit = math.huge })
end

-- Get all executed shots from all shotfiles in all configured repos.
function M.get_all_shots(project_filter)
  local shots = {}
  local repos = M.get_all_repo_paths()

  for _, repo_path in ipairs(repos) do
    local user, repo = repo_mod.get_git_remote_info(repo_path)
    if not user then
      user, repo = 'local', utils.get_basename(repo_path)
    end
    local repo_name = user .. '/' .. repo

    -- docs/shotfiles
    local prompts_dir = repo_path .. '/docs/shotfiles'
    for _, filepath in ipairs(find_md_files(prompts_dir)) do
      local project = repo_mod.detect_project_from_path(filepath)
      if repo_mod.repo_matches_filter(repo_name, project_filter) then
        local file_shots = parse.parse_shotfile(filepath)
        for _, shot in ipairs(file_shots) do
          shot.repo = repo_name
          shot.project = project
          table.insert(shots, shot)
        end
      end
    end

    -- projects/*/docs/shotfiles
    local projects_dir = repo_path .. '/projects'
    if utils.dir_exists(projects_dir) then
      local project_entries = vim.fn.readdir(projects_dir)
      if type(project_entries) == 'table' then
        for _, name in ipairs(project_entries) do
          local sub_prompts = projects_dir .. '/' .. name .. '/docs/shotfiles'
          for _, filepath in ipairs(find_md_files(sub_prompts)) do
            local project = repo_mod.detect_project_from_path(filepath)
            if repo_mod.repo_matches_filter(repo_name, project_filter) then
              local file_shots = parse.parse_shotfile(filepath)
              for _, shot in ipairs(file_shots) do
                shot.repo = repo_name
                shot.project = project
                table.insert(shots, shot)
              end
            end
          end
        end
      end
    end
  end

  table.sort(shots, function(a, b) return (a.time or 0) > (b.time or 0) end)
  return shots
end

return M

-- Dashboard data gathering module
-- Collects files and their open shots for the dashboard tree

local M = {}

local utils = require('shooter.utils')
local config = require('shooter.config')

-- Parse a file and find all shots (both open and done)
-- Returns { open = [...], total = N } where open is array of { number, line, preview }
function M.get_shots(filepath)
  local open_shots = {}
  local total_count = 0
  local file = io.open(filepath, 'r')
  if not file then return { open = open_shots, total = 0 } end

  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  for i, line in ipairs(lines) do
    -- Match done shots (## x shot N)
    if line:match('^##%s+x%s+shot%s+%d+') then
      total_count = total_count + 1
    -- Match open shots (## shot N)
    elseif line:match('^##%s+shot%s+(%d+)') then
      total_count = total_count + 1
      local shot_num = line:match('^##%s+shot%s+(%d+)')
      -- Get preview from next non-empty line
      local preview = ''
      for j = i + 1, math.min(i + 3, #lines) do
        if lines[j] and lines[j]:match('%S') then
          preview = lines[j]:sub(1, 50)
          if #lines[j] > 50 then preview = preview .. '...' end
          break
        end
      end
      table.insert(open_shots, {
        number = tonumber(shot_num),
        line = i,
        preview = preview,
      })
    end
  end

  return { open = open_shots, total = total_count }
end

-- Backward compatible: get only open shots
function M.get_open_shots(filepath)
  return M.get_shots(filepath).open
end

-- Get title from file (first # heading)
function M.get_file_title(filepath)
  local file = io.open(filepath, 'r')
  if not file then return nil end

  for line in file:lines() do
    local title = line:match('^#%s+(.+)$')
    if title then
      file:close()
      return title
    end
  end
  file:close()
  return nil
end

-- Helper: process files from a prompts directory
-- @param prompts_dir: path to prompts directory
-- @param result: result table to update (files, total_files, open_shots, total_shots)
-- @param project: project name or nil for root
local function process_prompts_dir(prompts_dir, result, project)
  if not utils.dir_exists(prompts_dir) then
    return
  end

  -- Get only root-level .md files (in-progress)
  local file_list = vim.fn.globpath(prompts_dir, '*.md', false, true)
  result.total_files = result.total_files + #file_list

  for _, filepath in ipairs(file_list) do
    local shot_data = M.get_shots(filepath)
    result.total_shots = result.total_shots + shot_data.total
    result.open_shots = result.open_shots + #shot_data.open

    -- Only include files with open shots in the files list
    if #shot_data.open > 0 then
      local name = vim.fn.fnamemodify(filepath, ':t')
      local title = M.get_file_title(filepath) or name
      -- Prefix with project name if in a project
      local display_name = project and (project .. '/' .. name) or name
      table.insert(result.files, {
        path = filepath,
        name = display_name,
        title = title,
        shots = shot_data.open,
        open_count = #shot_data.open,
        total_count = shot_data.total,
        project = project,
      })
    end
  end
end

-- Get all in-progress files with their shots for a single repo
-- Returns { files = [...], total_files = N, open_shots = N, total_shots = N }
-- Each file: { path, name, title, shots, open_count, total_count, project }
-- Includes files from both root and all projects
function M.get_repo_files(repo_path)
  local result = { files = {}, total_files = 0, open_shots = 0, total_shots = 0 }

  -- Process root prompts directory
  process_prompts_dir(repo_path .. '/plans/prompts', result, nil)

  -- Process project prompts directories
  local projects_dir = repo_path .. '/projects'
  if utils.dir_exists(projects_dir) then
    local handle = io.popen('ls -1 "' .. projects_dir .. '" 2>/dev/null')
    if handle then
      for project in handle:lines() do
        local project_prompts = projects_dir .. '/' .. project .. '/plans/prompts'
        process_prompts_dir(project_prompts, result, project)
      end
      handle:close()
    end
  end

  -- Sort by modification time (most recent first)
  table.sort(result.files, function(a, b)
    local a_time = vim.fn.getftime(a.path)
    local b_time = vim.fn.getftime(b.path)
    return a_time > b_time
  end)

  return result
end

-- Get repo name from path
function M.get_repo_name(repo_path)
  return vim.fn.fnamemodify(repo_path, ':t')
end

-- Get all configured repos with their files and counts
-- Returns array of { path, name, files, files_with_shots, total_files, open_shots, total_shots }
function M.get_all_repos()
  local repos = {}
  local seen = {}

  -- Helper to add a repo
  local function add_repo(repo_path)
    if seen[repo_path] then return end
    seen[repo_path] = true

    local repo_data = M.get_repo_files(repo_path)
    if #repo_data.files > 0 then
      table.insert(repos, {
        path = repo_path,
        name = M.get_repo_name(repo_path),
        files = repo_data.files,
        files_with_shots = #repo_data.files,
        total_files = repo_data.total_files,
        open_shots = repo_data.open_shots,
        total_shots = repo_data.total_shots,
      })
    end
  end

  -- Add current repo first
  local cwd = vim.fn.getcwd()
  if utils.dir_exists(cwd .. '/.git') then
    add_repo(cwd)
  end

  -- Add direct repo paths from config
  for _, path in ipairs(config.get('repos.direct_paths') or {}) do
    local expanded = utils.expand_path(path)
    if utils.dir_exists(expanded .. '/.git') then
      add_repo(expanded)
    end
  end

  -- Search directories for repos
  for _, dir in ipairs(config.get('repos.search_dirs') or {}) do
    local expanded = utils.expand_path(dir)
    if utils.dir_exists(expanded) then
      local handle = io.popen('ls -d "' .. expanded .. '"/*/ 2>/dev/null')
      if handle then
        for subdir in handle:lines() do
          subdir = subdir:gsub('/$', '')
          if utils.dir_exists(subdir .. '/.git') then
            add_repo(subdir)
          end
        end
        handle:close()
      end
    end
  end

  return repos
end

-- Get dashboard data for current repo only
function M.get_current_repo()
  local cwd = vim.fn.getcwd()
  local repo_data = M.get_repo_files(cwd)
  return {
    path = cwd,
    name = M.get_repo_name(cwd),
    files = repo_data.files,
    files_with_shots = #repo_data.files,
    total_files = repo_data.total_files,
    open_shots = repo_data.open_shots,
    total_shots = repo_data.total_shots,
  }
end

return M

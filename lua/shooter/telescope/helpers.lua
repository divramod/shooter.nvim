-- Telescope helper functions for shooter.nvim
local M = {}

local action_state = require('telescope.actions.state')
local utils = require('shooter.utils')

-- Get file modification time (returns seconds since epoch, or 0 on error)
function M.get_file_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if stat then
    return stat.mtime.sec
  end
  return 0
end

-- Persistent state storage (file -> { selections = set of shot numbers, cursor_row = number })
M.persistent_state = {}

-- Clear persistent state for a file
function M.clear_selection(filepath)
  if filepath then
    M.persistent_state[filepath] = nil
  else
    M.persistent_state = {}
  end
end

-- Get target file (current file if in prompts, or last edited)
-- Checks both root and project prompts paths
function M.get_target_file()
  local files_mod = require('shooter.core.files')
  local filepath = vim.fn.expand('%:p')

  -- Check if current file is in any prompts folder (root or project)
  if files_mod.is_in_prompts_folder(filepath) then
    return filepath, true
  end

  -- Try to find last edited file
  local last_file = files_mod.find_last_file()
  return last_file, false
end

-- Read file lines (from buffer if current, from disk otherwise)
function M.read_lines(target_file, is_current)
  if is_current then
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end
  local file = io.open(target_file, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  local lines = {}
  for line in content:gmatch('[^\n]*') do
    table.insert(lines, line)
  end
  return lines
end

-- Find open shots in file content (array of lines)
function M.find_open_shots(lines)
  local shots = {}
  local i = 1
  while i <= #lines do
    if lines[i]:match('^##%s+shot') and not lines[i]:match('^##%s+x%s+shot') then
      local start_line = i
      local end_line = #lines
      for j = start_line + 1, #lines do
        if lines[j]:match('^##%s+x?%s*shot') then
          end_line = j - 1
          break
        end
      end
      while end_line > start_line and lines[end_line]:match('^%s*$') do
        end_line = end_line - 1
      end
      table.insert(shots, {start_line = start_line, end_line = end_line, header_line = start_line})
      i = end_line + 1
    else
      i = i + 1
    end
  end
  return shots
end

-- Create shot entry for telescope picker
function M.make_shot_entry(shot, lines, target_file, is_current)
  local header = lines[shot.header_line]
  local shot_num = header:match('shot%s+(%d+)') or '?'
  local preview_lines = {}
  for idx = shot.start_line + 1, math.min(shot.start_line + 5, shot.end_line) do
    if lines[idx] and lines[idx] ~= '' then
      table.insert(preview_lines, lines[idx])
      if #preview_lines >= 3 then break end
    end
  end
  local preview = table.concat(preview_lines, ' | ')
  if #preview > 60 then preview = preview:sub(1, 60) .. '...' end
  return {
    shot_num = shot_num, header_line = shot.header_line,
    start_line = shot.start_line, end_line = shot.end_line,
    display = string.format('Shot %s: %s', shot_num, preview),
    lines = lines, target_file = target_file, is_current_file = is_current,
  }
end

-- Save current multi-selection and cursor position to persistent storage
function M.save_selection_state(prompt_bufnr, target_file)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local multi = picker:get_multi_selection()
  local selected_shots = {}
  for _, entry in ipairs(multi) do
    if entry.value and entry.value.shot_num then
      selected_shots[entry.value.shot_num] = true
    end
  end
  M.persistent_state[target_file] = {
    selections = selected_shots,
    cursor_row = picker:get_selection_row(),
  }
end

-- Restore selection and cursor position from persistent storage (with retry)
function M.restore_selection_state(prompt_bufnr, target_file, retry_count)
  retry_count = retry_count or 0
  local max_retries = 10

  local state = M.persistent_state[target_file]
  if not state then return end

  local saved = state.selections
  local saved_cursor = state.cursor_row

  local picker = action_state.get_current_picker(prompt_bufnr)
  if not picker or not picker._multi then
    if retry_count < max_retries then
      vim.defer_fn(function()
        M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
      end, 50)
    end
    return
  end

  local manager = picker.manager
  if not manager or type(manager) ~= 'table' then
    if retry_count < max_retries then
      vim.defer_fn(function()
        M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
      end, 50)
    end
    return
  end

  -- Check if entries are ready (manager has entries)
  local has_entries = false
  for _ in manager:iter() do
    has_entries = true
    break
  end
  if not has_entries and retry_count < max_retries then
    vim.defer_fn(function()
      M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
    end, 50)
    return
  end

  -- Find which rows need to be selected
  local rows_to_select = {}
  if saved and not vim.tbl_isempty(saved) then
    local row = 0
    for entry in manager:iter() do
      if entry.value and entry.value.shot_num and saved[entry.value.shot_num] then
        table.insert(rows_to_select, row)
      end
      row = row + 1
    end
  end

  -- Use telescope actions to programmatically select each row
  if #rows_to_select > 0 then
    local actions = require('telescope.actions')
    for _, target_row in ipairs(rows_to_select) do
      picker:set_selection(target_row)
      actions.toggle_selection(prompt_bufnr)
    end
  end

  -- Restore cursor to saved position
  if saved_cursor then
    picker:set_selection(saved_cursor)
  end
end

-- Get files for telescope picker (returns display paths without plans/prompts prefix)
-- opts table supports:
--   folder_filter: 'a', 'b', 'd', 'r', 'w', 'p' or full folder name
--   project: single project name (legacy support)
--   projects: array of project names to include (new)
--   sort_by_mtime: boolean to sort by modification time (new)
--   include_all_projects: boolean to include all projects (new)
function M.get_prompt_files(folder_filter_or_opts, project)
  local files_mod = require('shooter.core.files')
  local project_mod = require('shooter.core.project')

  -- Handle both legacy (folder_filter, project) and new (opts) calling conventions
  local opts = {}
  if type(folder_filter_or_opts) == 'table' then
    opts = folder_filter_or_opts
  else
    opts.folder_filter = folder_filter_or_opts
    opts.project = project
  end

  local results = {}
  local seen = {}

  -- Helper to add files from a single prompts directory
  local function add_from_prompts_dir(prompts_dir, display_prefix, proj_name)
    local search_dir = prompts_dir
    local glob_pattern
    if opts.folder_filter and opts.folder_filter ~= '' then
      search_dir = search_dir .. '/' .. opts.folder_filter
      glob_pattern = '**/*.md'
    else
      -- Get ALL files including subdirectories - session filtering handles folder selection
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

  -- Determine which projects to include
  if opts.include_all_projects then
    -- Include root + all projects
    local git_root = files_mod.get_git_root() or utils.cwd()
    -- Add root prompts
    add_from_prompts_dir(git_root .. '/plans/prompts', '', nil)
    -- Add all project prompts
    local projects = project_mod.list_projects()
    for _, p in ipairs(projects) do
      add_from_prompts_dir(p.path .. '/plans/prompts', p.name .. '/', p.name)
    end
  elseif opts.projects and #opts.projects > 0 then
    -- Include only specified projects
    for _, proj_name in ipairs(opts.projects) do
      local prompts_dir = files_mod.get_prompts_dir(proj_name)
      local prefix = proj_name and proj_name ~= '' and (proj_name .. '/') or ''
      add_from_prompts_dir(prompts_dir, prefix, proj_name)
    end
  else
    -- Single project (or root if nil)
    local prompts_dir = files_mod.get_prompts_dir(opts.project)
    add_from_prompts_dir(prompts_dir, '', opts.project)
  end

  -- Sort by mtime if requested
  if opts.sort_by_mtime then
    table.sort(results, function(a, b)
      return M.get_file_mtime(a.path) > M.get_file_mtime(b.path)
    end)
  end

  return results
end

-- Get prompt files from all configured repos
-- opts table supports:
--   folder_filter: folder to filter by
--   sort_by_mtime: boolean to sort by modification time
function M.get_all_repos_prompt_files(folder_filter_or_opts)
  local config = require('shooter.config')
  local results = {}
  local seen = {}

  -- Handle both legacy (folder_filter) and new (opts) calling conventions
  local opts = {}
  if type(folder_filter_or_opts) == 'table' then
    opts = folder_filter_or_opts
  else
    opts.folder_filter = folder_filter_or_opts
  end

  -- Helper to add files from a prompts directory
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

  -- Helper to add files from a repo (root + all projects)
  local function add_repo_files(repo_path, repo_name)
    -- Add root prompts
    add_prompts_dir(repo_path .. '/plans/prompts', repo_name .. '/', repo_name)

    -- Add project prompts if projects/ folder exists
    local projects_dir = repo_path .. '/projects'
    if utils.dir_exists(projects_dir) then
      local handle = io.popen('ls -1 "' .. projects_dir .. '" 2>/dev/null')
      if handle then
        for project in handle:lines() do
          local project_prompts = projects_dir .. '/' .. project .. '/plans/prompts'
          add_prompts_dir(project_prompts, repo_name .. '/' .. project .. '/', repo_name)
        end
        handle:close()
      end
    end
  end

  -- Add direct repo paths
  for _, path in ipairs(config.get('repos.direct_paths') or {}) do
    local expanded = utils.expand_path(path)
    if utils.dir_exists(expanded .. '/.git') then
      add_repo_files(expanded, vim.fn.fnamemodify(expanded, ':t'))
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
            add_repo_files(subdir, vim.fn.fnamemodify(subdir, ':t'))
          end
        end
        handle:close()
      end
    end
  end

  -- Sort by mtime if requested
  if opts.sort_by_mtime then
    table.sort(results, function(a, b)
      return M.get_file_mtime(a.path) > M.get_file_mtime(b.path)
    end)
  end

  return results
end

return M

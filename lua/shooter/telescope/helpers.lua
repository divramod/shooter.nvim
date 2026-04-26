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
-- show_file: if true, include filename in display (for multi-file mode)
function M.make_shot_entry(shot, lines, target_file, is_current, show_file)
  local shots_mod = require('shooter.core.shots')
  local header = lines[shot.header_line]
  local shot_num = header:match('shot%s+(%d+)') or '?'

  -- Use header description if present, otherwise first content line(s)
  local header_desc = shots_mod.parse_shot_header_text(header)
  local preview
  if header_desc then
    preview = header_desc
  else
    local preview_lines = {}
    for idx = shot.start_line + 1, math.min(shot.start_line + 5, shot.end_line) do
      if lines[idx] and lines[idx] ~= '' then
        table.insert(preview_lines, lines[idx])
        if #preview_lines >= 3 then break end
      end
    end
    preview = table.concat(preview_lines, ' | ')
  end
  if #preview > 60 then preview = preview:sub(1, 60) .. '...' end

  local display
  if show_file then
    local filename = vim.fn.fnamemodify(target_file, ':t:r')  -- filename without extension
    display = string.format('[%s] Shot %s: %s', filename, shot_num, preview)
  else
    display = string.format('Shot %s: %s', shot_num, preview)
  end

  return {
    shot_num = shot_num, header_line = shot.header_line,
    start_line = shot.start_line, end_line = shot.end_line,
    display = display, lines = lines, target_file = target_file, is_current_file = is_current,
  }
end

-- Get all prompt files from current repo
function M.get_repo_prompt_files()
  local files_mod = require('shooter.core.files')
  local git_root = files_mod.get_git_root()
  if not git_root then return {} end
  local prompts_dir = git_root .. '/docs/shotfiles'
  if not utils.dir_exists(prompts_dir) then return {} end
  return vim.fn.globpath(prompts_dir, '**/*.md', false, true)
end

-- Get all open shots from all shotfiles in the repo
function M.get_all_repo_shots()
  local all_shots = {}
  local prompt_files = M.get_repo_prompt_files()

  for _, filepath in ipairs(prompt_files) do
    local lines = M.read_lines(filepath, false)
    if lines then
      local shots = M.find_open_shots(lines)
      for _, shot in ipairs(shots) do
        table.insert(all_shots, M.make_shot_entry(shot, lines, filepath, false, true))
      end
    end
  end

  return all_shots
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

-- Get files for telescope picker (returns display paths without docs/shotfiles prefix)
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

  -- Helper: add per-plan idea.md / spec.md / masterplan.md from
  -- docs/plans/<NNNN-slug>/ (alongside metaplan.md). These are picker-
  -- visible plan files: idea.md is a real shotfile, while spec.md and
  -- per-plan masterplan.md are plain markdown that we still want
  -- reachable via the picker / <space>l.
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

  -- Determine which projects to include
  if opts.include_all_projects then
    -- Include root + all projects
    -- Always resolve from main worktree so shotfiles are visible from any worktree
    local git_worktree = require('shooter.tools.git_worktree')
    local git_root = git_worktree.get_main_worktree() or files_mod.get_git_root() or utils.cwd()
    -- Add root prompts
    add_from_prompts_dir(git_root .. '/docs/shotfiles', '', nil)
    -- Add per-plan files (metaplan + idea/spec/masterplan)
    add_plan_files(git_root)
    -- Add all project prompts (also from main worktree)
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
    add_prompts_dir(repo_path .. '/docs/shotfiles', repo_name .. '/', repo_name)

    -- Add project prompts if projects/ folder exists
    local projects_dir = repo_path .. '/projects'
    if utils.dir_exists(projects_dir) then
      local handle = io.popen('ls -1 "' .. projects_dir .. '" 2>/dev/null')
      if handle then
        for project in handle:lines() do
          local project_prompts = projects_dir .. '/' .. project .. '/docs/shotfiles'
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

-- Get bullet files from the bullets directory
-- opts:
--   scope: 'file' (current shotfile), 'repo' (current repo), 'all' (all repos)
--   shotfile_basename: filter by shotfile name (for scope='file')
--   repo_slug: filter by repo name (for scope='repo')
function M.get_bullet_files(opts)
  opts = opts or {}
  local ext_config = require('shooter.core.ext_config')
  local bullets_root = ext_config.bullets_dir()
  local results = {}

  if not utils.dir_exists(bullets_root) then return results end

  local function add_bullets_from_dir(dir, repo_name)
    if not utils.dir_exists(dir) then return end
    local files = vim.fn.globpath(dir, '*.md', false, true)
    for _, filepath in ipairs(files) do
      local filename = vim.fn.fnamemodify(filepath, ':t')
      local display = repo_name and (repo_name .. '/' .. filename) or filename
      table.insert(results, {
        display = display,
        path = filepath,
        repo = repo_name,
        _mtime = M.get_file_mtime(filepath),
      })
    end
  end

  if opts.scope == 'file' then
    local repo_slug = opts.repo_slug
    local basename = opts.shotfile_basename
    if not repo_slug or not basename then return results end
    local dir = bullets_root .. '/' .. repo_slug
    if not utils.dir_exists(dir) then return results end
    local files = vim.fn.globpath(dir, basename .. '_*.md', false, true)
    for _, filepath in ipairs(files) do
      local filename = vim.fn.fnamemodify(filepath, ':t')
      table.insert(results, {
        display = filename,
        path = filepath,
        repo = repo_slug,
        _mtime = M.get_file_mtime(filepath),
      })
    end
  elseif opts.scope == 'repo' then
    local repo_slug = opts.repo_slug
    if not repo_slug then return results end
    add_bullets_from_dir(bullets_root .. '/' .. repo_slug, nil)
  else
    local handle = io.popen('ls -1 "' .. bullets_root .. '" 2>/dev/null')
    if handle then
      for repo_name in handle:lines() do
        local repo_dir = bullets_root .. '/' .. repo_name
        if vim.fn.isdirectory(repo_dir) == 1 then
          add_bullets_from_dir(repo_dir, repo_name)
        end
      end
      handle:close()
    end
  end

  table.sort(results, function(a, b)
    return (a._mtime or 0) > (b._mtime or 0)
  end)

  return results
end

return M

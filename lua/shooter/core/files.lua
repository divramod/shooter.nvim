-- File operations for shooter.nvim
-- Creating, listing, and managing shooter files

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Last shotfile tracking (in-memory + persisted to disk)
local _last_shotfile = nil

local function _last_shotfile_path_for_main()
  local git_root = M.get_git_root()
  if not git_root then return nil end
  local storage = require('shooter.session.storage')
  local ext_config = require('shooter.core.ext_config')
  local slug = storage.get_repo_slug(git_root)
  return ext_config.last_shotfile_path(slug:gsub('/', '_'))
end

local function _persist_last_shotfile(filepath)
  local path = _last_shotfile_path_for_main()
  if not path then return end
  utils.ensure_dir(utils.get_dirname(path))
  local f = io.open(path, 'w')
  if f then f:write(filepath); f:close() end
end

local function _load_last_shotfile()
  local path = _last_shotfile_path_for_main()
  if not path then return nil end
  local f = io.open(path, 'r')
  if f then
    local content = f:read('*l'); f:close()
    -- Reject stale entries that point into a worktree copy of the shotfiles
    -- tree (pre-shot-6 persisted state) so < >l always returns to main.
    if content and vim.fn.filereadable(content) == 1
        and M.is_last_trackable(content) then
      return content
    end
  end
  return nil
end

-- docs/plans/metaplan.md is trackable so < >l can return to it when
-- it was the last thing the user opened. Restricted to the MAIN worktree —
-- a metaplan.md in a numbered worktree is intentionally NOT recognised so
-- < >l never resurfaces a worktree copy.
function M.is_metaplan(path)
  if not path then return false end
  local main_root = M.get_git_root()
  if not main_root then return false end
  return path == main_root .. '/docs/plans/metaplan.md'
end

-- True for `<main_root>/docs/plans/<NNNN-slug>/<kind>.md` where kind is one
-- of the per-plan files we want < >l / the shotfile picker to track. Same
-- main-worktree-only restriction as is_metaplan.
function M.is_plan_file(path, kind)
  if not path then return false end
  local main_root = M.get_git_root()
  if not main_root then return false end
  local pattern = '^' .. vim.pesc(main_root)
    .. '/docs/plans/%d%d%d%d%-[%l%d][%w%-]*/'
    .. (kind or '[a-z]+') .. '%.md$'
  return path:match(pattern) ~= nil
end

-- Per-plan idea.md: the only plan-folder file that is treated as a SHOTFILE
-- (full shot syntax + shot commands like <space>n / <space>1-9). spec.md and
-- per-plan masterplan.md are last-trackable but plain markdown.
function M.is_plan_idea(path)
  return M.is_plan_file(path, 'idea')
end

-- Predicate used by track/load/find for the "last opened file" flow.
-- A path is "last-trackable" when reopening it makes sense as a return
-- target: a shotfile, the global metaplan, or any per-plan idea / spec /
-- masterplan file.
function M.is_last_trackable(path)
  if not path then return false end
  return M.is_in_prompts_folder(path)
    or M.is_metaplan(path)
    or M.is_plan_file(path, 'idea')
    or M.is_plan_file(path, 'spec')
    or M.is_plan_file(path, 'masterplan')
end

-- Called by syntax.lua on BufEnter for shotfiles (and for metaplan.md).
-- Only tracks files that would be valid targets for < >l, so we never bring
-- the user back to an unrelated buffer.
function M.track_last_shotfile(filepath)
  if not M.is_last_trackable(filepath) then return end
  _last_shotfile = filepath
  _persist_last_shotfile(filepath)
end

-- Helper: Get the git root that owns shotfile state — always the main
-- worktree's toplevel, regardless of cwd. Shotfiles live on one branch; this
-- keeps every command (open, edit, rename, move, pick, list, fix) pointed at
-- that single source of truth, so a worktree never edits its own copy.
-- Falls back to the current toplevel when `git worktree list` is unavailable.
function M.get_git_root()
  local wt_lines = vim.fn.systemlist('git worktree list --porcelain')
  if vim.v.shell_error == 0 then
    for _, line in ipairs(wt_lines) do
      local path = line:match('^worktree (.+)')
      if path and path ~= '' then return path end
    end
  end
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #root > 0 then return root[1] end
  return nil
end

-- Helper: Get the current cwd's git toplevel. Use this only for non-shotfile
-- operations that should follow the worktree the user is actually in (e.g.
-- "last edited file in repo" navigation).
function M.get_cwd_git_root()
  local result = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end
  return nil
end

-- Helper: Get git root (toplevel) that contains a given file path.
-- Works across worktrees — each worktree returns its own toplevel.
function M.get_file_git_root(filepath)
  if not filepath or filepath == '' then return nil end
  local dir = vim.fn.fnamemodify(filepath, ':h')
  if dir == '' or vim.fn.isdirectory(dir) ~= 1 then return nil end
  local result = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #result > 0 and result[1] ~= '' then
    return result[1]
  end
  return nil
end

-- Open a shotfile path, cd-ing to its git root first if different from cwd.
-- Keeps buffer and cwd aligned when the file lives in another worktree.
function M.open_shotfile(filepath)
  if not filepath or filepath == '' then return end
  local target_root = M.get_file_git_root(filepath)
  if target_root and target_root ~= vim.fn.getcwd() then
    vim.cmd('cd ' .. vim.fn.fnameescape(target_root))
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
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

-- Helper: Check if path is in the prompts folder of the main worktree only.
-- A shotfile living inside a numbered worktree is deliberately NOT recognised
-- — shotfiles are single-source on the main branch and worktree copies must
-- not be edited through shooter commands.
function M.is_in_prompts_folder(path)
  if not path then return false end
  local git_root = M.get_git_root()
  if not git_root then return false end
  if path:find(git_root .. '/docs/shotfiles', 1, true) then
    return true
  end
  if path:find(git_root .. '/projects/.+/docs/shotfiles') then
    return true
  end
  -- Per-plan idea.md is also a shotfile (gets shot syntax + shot commands).
  if M.is_plan_idea(path) then
    return true
  end
  return false
end

-- Helper: Check if current file is a next-action/shooter file
function M.is_shooter_file(filepath)
  filepath = filepath or vim.fn.expand('%:p')
  return M.is_in_prompts_folder(filepath)
end

-- Get shooter files from directory (returns display paths without docs/shotfiles prefix)
-- project = nil means root level, string means specific project
function M.get_prompt_files(project)
  local prompts_dir = M.get_prompts_dir(project)
  local files = vim.fn.globpath(prompts_dir, '**/*.md', false, true)
  local results = {}

  for _, file in ipairs(files) do
    -- Store both display path (without docs/shotfiles/) and full path
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

-- Slugify a single path segment (lowercase, non-alnum → dashes, dedupe,
-- trim). Exposed so callers can sanitise multi-segment paths.
function M.slugify_segment(segment)
  if not segment or segment == '' then return '' end
  local slug = segment:lower()
  slug = slug:gsub('%s+', '-')
  slug = slug:gsub('[^%w%-]', '')
  slug = slug:gsub('%-+', '-')
  slug = slug:gsub('^%-', ''):gsub('%-$', '')
  return slug
end

-- Slugify every segment of a slash-separated path. Preserves an empty
-- trailing segment so "foo bar/" stays a folder-like "foo-bar/" input.
function M.slugify_path(path)
  if not path or path == '' then return '' end
  local trailing = path:sub(-1) == '/'
  local parts = {}
  for seg in path:gmatch('[^/]+') do
    table.insert(parts, M.slugify_segment(seg))
  end
  local out = table.concat(parts, '/')
  if trailing then out = out .. '/' end
  return out
end

-- Generate filename from title (slug.md)
function M.generate_filename(title)
  return string.format('%s.md', M.slugify_segment(title))
end

-- Compute title from file path (relative path from shotfiles root, without .md)
-- e.g., /repo/docs/shotfiles/test/test.md → "test/test"
-- e.g., /repo/docs/shotfiles/test.md → "test"
function M.title_from_path(filepath)
  local match = filepath:match('/docs/shotfiles/(.+)$')
  if match then
    return match:gsub('%.md$', '')
  end
  -- Plan-folder files (plan.md / context.md / spec.md / idea.md): title is
  -- "docs/plans/<NNNN-slug>/<basename>".
  local plan_match = filepath:match('/(docs/plans/[^/]+/[^/]+)$')
  if plan_match then
    return plan_match:gsub('%.md$', '')
  end
  return vim.fn.fnamemodify(filepath, ':t:r')
end

-- Update the # title heading in a file on disk
function M.update_file_title(filepath, new_title)
  local content = utils.read_file(filepath)
  if not content then return false end
  local safe_title = new_title:gsub('%%', '%%%%')
  -- Use [ \t]+ instead of %s+ to avoid matching across newlines
  local updated = content:gsub('^(#[ \t]+)[^\n]+', '%1' .. safe_title, 1)
  if updated == content then
    updated = content:gsub('\n(#[ \t]+)[^\n]+', '\n%1' .. safe_title, 1)
  end
  if updated ~= content then
    utils.write_file(filepath, updated)
    return true
  end
  return false
end

-- Create new shooter file (project-aware)
-- project = nil means root level, string means specific project
function M.create_file(title, folder, initial_content, project)
  folder = folder or ''

  -- Let users type `sub/dir/my title` to drop the shotfile in a nested folder.
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

  local filename = M.generate_filename(title)
  local git_root = M.get_git_root() or utils.cwd()
  local full_path = git_root .. '/' .. base_path .. '/' .. filename

  -- Ensure directory exists
  local dir = utils.get_dirname(full_path)
  utils.ensure_dir(dir)

  -- Build the title including folder path
  local slug = filename:gsub('%.md$', '')
  local path_title = (folder ~= '') and (folder .. '/' .. slug) or slug

  -- Build file content
  local file_content

  if initial_content and initial_content ~= '' then
    -- Check if content contains shot pattern
    local has_shot_pattern = initial_content:match(config.get('patterns.shot_header'))

    if has_shot_pattern then
      file_content = string.format('# %s\n\n\n%s\n', path_title, initial_content)
    else
      file_content = string.format('# %s\n\n## shot 1\n%s\n', path_title, initial_content)
    end
  else
    file_content = string.format('# %s\n\n## shot 1\n\n', path_title)
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
-- Uses tracked shotfile (set by BufEnter autocmd) first, falls back to ls -t
function M.find_last_file(project)
  -- Primary: return Neovim-tracked last shotfile (must live under main,
  -- or be docs/plans/metaplan.md)
  if _last_shotfile and vim.fn.filereadable(_last_shotfile) == 1
      and M.is_last_trackable(_last_shotfile) then
    return _last_shotfile
  end

  -- Secondary: check persisted state (survives Neovim restarts)
  local persisted = _load_last_shotfile()
  if persisted then
    _last_shotfile = persisted
    return persisted
  end

  -- Fallback: filesystem mtime (unreliable but better than nothing on first use)
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

-- Ensure theme shotfiles exist based on .hal/util/shooter/themes.json
-- Creates missing shotfiles with a simple "# <title>" header
function M.ensure_theme_shotfiles()
  local git_root = M.get_git_root()
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

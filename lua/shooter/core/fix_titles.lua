-- Fix H1 titles in shotfiles to match the canonical path-based format.
-- Canonical rule:
--   .hal/util/shooter/shotfiles/foo.md            → "# foo"
--   .hal/util/shooter/shotfiles/some/test/foo.md  → "# some/test/foo"

local utils = require('shooter.utils')
local files = require('shooter.core.files')

local M = {}

-- Read the first H1 title from file content (within first 50 lines).
-- Returns title string (trimmed) or nil if none found.
function M.read_h1(content)
  if not content then return nil end
  local lines = vim.split(content, '\n', { plain = true })
  for i = 1, math.min(#lines, 50) do
    local title = lines[i]:match('^#%s+(.*)$')
    if title then
      return (title:gsub('%s*$', ''))
    end
  end
  return nil
end

-- Fix the H1 title of a single shotfile to match its canonical path-based title.
-- Returns: changed_bool, old_title, new_title, err
function M.fix_title_in_file(filepath)
  local content, read_err = utils.read_file(filepath)
  if not content then return false, nil, nil, read_err end

  local new_title = files.title_from_path(filepath)
  local old_title = M.read_h1(content)

  if old_title == new_title then
    return false, old_title, new_title, nil
  end

  if old_title then
    local updated = files.update_file_title(filepath, new_title)
    if not updated then return false, old_title, new_title, 'update failed' end
  else
    local prefix = '# ' .. new_title .. '\n\n'
    local ok, write_err = utils.write_file(filepath, prefix .. content)
    if not ok then return false, nil, new_title, write_err end
  end

  return true, old_title, new_title, nil
end

-- Collect all shotfile paths under .hal/util/shooter/shotfiles for the repo.
-- Also includes projects/*/.hal/util/shooter/shotfiles for mono-repos.
function M.collect_shotfiles(git_root)
  git_root = git_root or files.get_git_root()
  if not git_root then return {} end

  local dirs = {}
  local root_dir = git_root .. '/.hal/util/shooter/shotfiles'
  if utils.dir_exists(root_dir) then
    table.insert(dirs, root_dir)
  end

  local projects_dir = git_root .. '/projects'
  if utils.dir_exists(projects_dir) then
    for _, name in ipairs(vim.fn.readdir(projects_dir)) do
      local proj_dir = projects_dir .. '/' .. name .. '/.hal/util/shooter/shotfiles'
      if utils.dir_exists(proj_dir) then
        table.insert(dirs, proj_dir)
      end
    end
  end

  local results = {}
  for _, dir in ipairs(dirs) do
    local md_files = vim.fn.globpath(dir, '**/*.md', false, true)
    for _, path in ipairs(md_files) do
      table.insert(results, path)
    end
  end
  return results
end

-- Walk all shotfiles in the repository and fix their titles.
-- Returns: { checked = int, fixed = int, changes = { {path, old, new} }, errors = { {path, err} } }
function M.fix_all_titles(git_root)
  local stats = { checked = 0, fixed = 0, changes = {}, errors = {} }

  for _, filepath in ipairs(M.collect_shotfiles(git_root)) do
    stats.checked = stats.checked + 1
    local changed, old_title, new_title, err = M.fix_title_in_file(filepath)
    if err then
      table.insert(stats.errors, { path = filepath, err = err })
    elseif changed then
      stats.fixed = stats.fixed + 1
      table.insert(stats.changes, { path = filepath, old = old_title, new = new_title })
    end
  end

  return stats
end

-- Build a git commit message summarizing the title fixes.
-- Exposed for testing.
function M.build_commit_message(git_root, changes)
  local n = #changes
  local subject = string.format('fix(shotfiles): canonicalize %d H1 title%s',
    n, n == 1 and '' or 's')
  local body_lines = {}
  for _, c in ipairs(changes) do
    local rel = c.path
    if git_root and rel:sub(1, #git_root + 1) == git_root .. '/' then
      rel = rel:sub(#git_root + 2)
    end
    local from = c.old and ('"' .. c.old .. '"') or '(missing)'
    table.insert(body_lines, string.format('- %s: %s -> "%s"', rel, from, c.new))
  end
  return subject .. '\n\n' .. table.concat(body_lines, '\n') .. '\n'
end

-- git add + git commit the fixed shotfiles. Commits only those paths, leaving
-- any other staged changes in the index untouched.
-- Returns: ok_bool, err_or_nil
function M.commit_fixes(git_root, changes)
  if not git_root or not changes or #changes == 0 then
    return true, nil
  end

  local rel_paths = {}
  for _, c in ipairs(changes) do
    if c.path:sub(1, #git_root + 1) == git_root .. '/' then
      table.insert(rel_paths, c.path:sub(#git_root + 2))
    end
  end
  if #rel_paths == 0 then return true, nil end

  local add_cmd = { 'git', '-C', git_root, 'add', '--' }
  for _, p in ipairs(rel_paths) do table.insert(add_cmd, p) end
  local add_out = vim.fn.system(add_cmd)
  if vim.v.shell_error ~= 0 then
    return false, 'git add failed: ' .. ((add_out or ''):gsub('\n', ' '))
  end

  local message = M.build_commit_message(git_root, changes)
  local commit_cmd = { 'git', '-C', git_root, 'commit', '-m', message, '--' }
  for _, p in ipairs(rel_paths) do table.insert(commit_cmd, p) end
  local commit_out = vim.fn.system(commit_cmd)
  if vim.v.shell_error ~= 0 then
    return false, 'git commit failed: ' .. ((commit_out or ''):gsub('\n', ' '))
  end

  return true, nil
end

return M

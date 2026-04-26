-- Plan delete + preflight checks.

local io_mod = require('shooter.plans.metaplan.io')
local numbering = require('shooter.plans.metaplan.numbering')
local rename = require('shooter.plans.metaplan.rename')

local M = {}

-- True when `path` is missing or has at most one non-blank line and that
-- line is a markdown heading.
function M.is_stub_file(path)
  if not path or path == '' then return false end
  if vim.fn.filereadable(path) ~= 1 then return false end
  local content = io_mod.read_file(path) or ''
  local non_blank = {}
  for _, line in ipairs(vim.split(content, '\n', { plain = true })) do
    if line:match('%S') then table.insert(non_blank, line) end
  end
  if #non_blank == 0 then return true end
  if #non_blank == 1 and non_blank[1]:match('^#') then return true end
  return false
end

-- True if `dir` exists AND contains at least one non-stub file or any
-- subdirectory.
function M.folder_has_content(dir)
  if not dir or dir == '' then return false end
  if vim.fn.isdirectory(dir) ~= 1 then return false end
  for _, name in ipairs(vim.fn.readdir(dir)) do
    local p = dir .. '/' .. name
    if vim.fn.isdirectory(p) == 1 then return true end
    if vim.fn.filereadable(p) == 1 and not M.is_stub_file(p) then
      return true
    end
  end
  return false
end

-- Pre-flight delete check for MAIN's copy of the plan folder.
function M.delete_plan_preflight(git_root, name, force)
  if force then return true end
  local files = numbering.plan_files_in_worktree(git_root, name)
  local extras = {}
  for _, f in ipairs(files) do
    if f ~= 'idea.md' then table.insert(extras, f) end
  end
  if #extras > 0 then
    return false, name .. ' has [' .. table.concat(extras, ', ') .. ']'
  end
  return true
end

-- Delete a plan in MAIN: remove folder + metaplan entry, run fix(), commit.
function M.delete_plan(git_root, name, opts)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not name or name == '' then return false, 'no plan name' end
  opts = opts or {}
  if opts.folder == nil then opts.folder = true end

  if opts.folder then
    local ok, reason = M.delete_plan_preflight(git_root, name, opts.force)
    if not ok then return false, reason end
  end

  local plans_rel = 'docs/plans'
  local folder = git_root .. '/' .. plans_rel .. '/' .. name
  if opts.folder and vim.fn.isdirectory(folder) == 1 then
    for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
      io_mod.close_buf_for(folder .. '/' .. kind .. '.md')
    end
    local _, err = io_mod.git(git_root, { 'rm', '-rf', '--', plans_rel .. '/' .. name })
    if err ~= 0 then vim.fn.delete(folder, 'rf') end
  end

  if vim.fn.isdirectory(folder) ~= 1 then
    local ok, err = rename.remove_metaplan_entry(git_root, name)
    if not ok then return false, err end
  end

  -- Lazy-require fix to break import cycle.
  local fix = require('shooter.plans.metaplan.fix')
  local fok, ferr = fix.fix(git_root)
  if not fok then return false, ferr end
  local cok, cmsg, committed = io_mod.commit_plans(git_root,
    'chore(plans): delete ' .. name)
  if not cok then return false, cmsg end
  return true, committed and 'deleted' or 'deleted (nothing to commit)'
end

return M

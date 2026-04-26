-- Plan numbering: classification, used-number collection, gap-fill index.

local M = {}

-- Classify a plan into one of the auto-managed sections based on the
-- files inside docs/plans/<plan_name>/ in ANY worktree.
--   * hal.yml has `started_at:` with a non-empty value → 'in progress'
--   * masterplan.md present → 'planned'
--   * spec.md present → 'specified'
--   * else → 'next plans'
-- `## done` is sticky — only mark_done puts a plan there.
function M.classify_plan(git_root, plan_name, worktree_roots)
  if not git_root or not plan_name or plan_name == '' then
    return 'next plans'
  end
  worktree_roots = worktree_roots or M.list_worktree_roots(git_root)
  local has_started, has_masterplan, has_spec = false, false, false
  for _, root in ipairs(worktree_roots) do
    local folder = root .. '/docs/plans/' .. plan_name
    if vim.fn.isdirectory(folder) == 1 then
      if not has_started
          and vim.fn.filereadable(folder .. '/hal.yml') == 1 then
        local f = io.open(folder .. '/hal.yml', 'r')
        if f then
          local content = f:read('*a') or ''
          f:close()
          for line in content:gmatch('[^\n]+') do
            if line:match('^%s*started_at:[ \t]*%d') then
              has_started = true
              break
            end
          end
        end
      end
      if not has_masterplan
          and vim.fn.filereadable(folder .. '/masterplan.md') == 1 then
        has_masterplan = true
      end
      if not has_spec
          and vim.fn.filereadable(folder .. '/spec.md') == 1 then
        has_spec = true
      end
    end
    if has_started then break end
  end
  if has_started then return 'in progress' end
  if has_masterplan then return 'planned' end
  if has_spec then return 'specified' end
  return 'next plans'
end

function M.plan_files_in_worktree(wt_root, plan_name)
  local out = {}
  if not wt_root or not plan_name then return out end
  local folder = wt_root .. '/docs/plans/' .. plan_name
  if vim.fn.isdirectory(folder) ~= 1 then return out end
  for _, name in ipairs(vim.fn.readdir(folder)) do
    table.insert(out, name)
  end
  return out
end

-- Enumerate every worktree of the repo at git_root.
function M.list_worktree_roots(git_root)
  if not git_root or git_root == '' then return {} end
  local out = vim.fn.system({ 'git', '-C', git_root, 'worktree', 'list',
    '--porcelain' })
  if vim.v.shell_error ~= 0 then return { git_root } end
  local seen, roots = {}, {}
  for line in out:gmatch('[^\n]+') do
    local path = line:match('^worktree%s+(.+)$')
    if path then
      local resolved = vim.uv.fs_realpath(path) or path
      if not seen[resolved] and vim.fn.isdirectory(resolved) == 1 then
        seen[resolved] = true
        table.insert(roots, resolved)
      end
    end
  end
  if #roots == 0 then return { git_root } end
  return roots
end

-- Build the set of plan numbers already committed across worktrees + non-tentative
-- metaplan sections. See the original docstring in metaplan.lua history for the
-- detailed rationale on tentative_set / tentative_slugs / main_slugs.
function M.collect_used_numbers(git_root, sections, worktree_roots)
  local used = {}
  local function add(n) if n and n > 0 then used[n] = true end end

  worktree_roots = worktree_roots or M.list_worktree_roots(git_root)
  sections = sections or {}

  local tentative_set = {}
  local tentative_slugs = {}
  for _, entry in ipairs(sections['next plans'] or {}) do
    local pn = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
    if pn then tentative_set[pn] = true end
    local slug = entry.text:match('^%d%d%d%d%-([%l%d][%w%-]*)')
    if slug then tentative_slugs[slug] = true end
  end

  local main_slugs = {}
  for _, sect in ipairs({ 'in progress', 'planned', 'specified', 'done' }) do
    for _, entry in ipairs(sections[sect] or {}) do
      local slug = entry.text:match('^%d%d%d%d%-([%l%d][%w%-]*)')
      if slug then main_slugs[slug] = true end
    end
  end
  local main_resolved = git_root and (vim.uv.fs_realpath(git_root) or git_root)
  if main_resolved then
    local main_plans_dir = main_resolved .. '/docs/plans'
    if vim.fn.isdirectory(main_plans_dir) == 1 then
      for _, name in ipairs(vim.fn.readdir(main_plans_dir)) do
        local slug = name:match('^%d%d%d%d%-([%l%d][%w%-]*)$')
        if slug then main_slugs[slug] = true end
      end
    end
  end

  for _, root in ipairs(worktree_roots) do
    local root_resolved = vim.uv.fs_realpath(root) or root
    local is_main = (root_resolved == main_resolved)
    local plans_dir = root .. '/docs/plans'
    if vim.fn.isdirectory(plans_dir) == 1 then
      for _, name in ipairs(vim.fn.readdir(plans_dir)) do
        local pname = name:match('^((%d%d%d%d)%-[%l%d][%w%-]*)$')
        if pname then
          local slug = name:match('^%d%d%d%d%-([%l%d][%w%-]*)$')
          local skip
          if is_main then
            skip = tentative_set[pname]
          else
            skip = main_slugs[slug] or tentative_slugs[slug]
          end
          if not skip then
            add(tonumber(name:match('^(%d%d%d%d)%-')))
          end
        end
      end
    end
  end

  for _, sect in ipairs({ 'in progress', 'planned', 'specified', 'done' }) do
    for _, entry in ipairs(sections[sect] or {}) do
      add(tonumber(entry.text:match('^(%d%d%d%d)%-')))
    end
  end
  return used
end

-- Smallest N >= 1 where exactly k-1 smaller numbers are also free in `used`.
function M.next_plans_number_at(used, k)
  used = used or {}
  if not k or k < 1 then k = 1 end
  local n, count = 0, 0
  while count < k do
    n = n + 1
    if not used[n] then count = count + 1 end
  end
  return n
end

function M.next_free_plan_number(git_root, sections)
  local used = M.collect_used_numbers(git_root, sections)
  local current = (sections or {})['next plans'] or {}
  return M.next_plans_number_at(used, #current + 1)
end

return M

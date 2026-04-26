-- Top-level conveniences: path/title/alias and cursor-line plan opens.

local parse = require('shooter.plans.metaplan.parse')

local M = {}

function M.get_path(git_root)
  return git_root .. '/docs/plans/metaplan.md'
end

function M.get_alias(git_root)
  local f = io.open(git_root .. '/.hal/ALIAS', 'r')
  if not f then return nil end
  local s = f:read('*a') or ''
  f:close()
  s = s:match('^%s*(.-)%s*$')
  if s == '' then return nil end
  return s
end

function M.get_title(git_root)
  local repo = vim.fn.fnamemodify(git_root, ':t')
  local alias = M.get_alias(git_root)
  if alias then
    return string.format('# metaplan %s (%s)', repo, alias)
  end
  return string.format('# metaplan %s', repo)
end

-- Path to the idea.md for a plan: docs/plans/<plan_name>/idea.md.
function M.idea_path(git_root, plan_name)
  return git_root .. '/docs/plans/' .. plan_name .. '/idea.md'
end

-- Open/create the idea.md corresponding to the plan referenced on the given
-- line. Returns ok_bool, action_string.
function M.edit_plan_at_line(git_root, line)
  if not git_root or git_root == '' then return false, 'no git root' end
  local plan_name = parse.extract_plan_name(line)
  if not plan_name then return false, 'no plan on current line' end

  -- Lazy-require to avoid circular dep between meta ↔ idea.
  local idea = require('shooter.plans.metaplan.idea')
  local ok, msg = idea.ensure_plan_idea(git_root, plan_name)
  if not ok then return false, msg end

  vim.cmd('edit ' .. vim.fn.fnameescape(M.idea_path(git_root, plan_name)))
  return true, msg == 'exists' and 'opened' or msg
end

-- Open docs/plans/<NNNN-slug>/<kind>.md for the plan referenced on the line.
function M.open_plan_file(git_root, line, kind)
  if not git_root or git_root == '' then return false, 'no git root' end
  if kind ~= 'plan' and kind ~= 'context' and kind ~= 'spec'
      and kind ~= 'masterplan' then
    return false, 'invalid kind: ' .. tostring(kind)
  end
  local plan_name = parse.extract_plan_name(line)
  if not plan_name then return false, 'no plan on current line' end
  local path = git_root .. '/docs/plans/' .. plan_name .. '/' .. kind .. '.md'
  if vim.fn.filereadable(path) ~= 1 then
    return false, 'no ' .. kind .. '.md for ' .. plan_name
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  return true, 'opened'
end

return M

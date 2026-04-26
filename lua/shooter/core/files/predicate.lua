-- File-classification predicates.
-- All "is this path a shooter-tracked file?" checks live here.

local git = require('shooter.core.files.git')

local M = {}

function M.is_metaplan(path)
  if not path then return false end
  local main_root = git.get_git_root()
  if not main_root then return false end
  return path == main_root .. '/docs/plans/metaplan.md'
end

function M.is_plan_file(path, kind)
  if not path then return false end
  local main_root = git.get_git_root()
  if not main_root then return false end
  local pattern = '^' .. vim.pesc(main_root)
    .. '/docs/plans/%d%d%d%d%-[%l%d][%w%-]*/'
    .. (kind or '[a-z]+') .. '%.md$'
  return path:match(pattern) ~= nil
end

function M.is_plan_idea(path)
  return M.is_plan_file(path, 'idea')
end

function M.is_in_prompts_folder(path)
  if not path then return false end
  local git_root = git.get_git_root()
  if not git_root then return false end
  if path:find(git_root .. '/docs/shotfiles', 1, true) then
    return true
  end
  if path:find(git_root .. '/projects/.+/docs/shotfiles') then
    return true
  end
  if M.is_plan_idea(path) then
    return true
  end
  return false
end

function M.is_shooter_file(filepath)
  filepath = filepath or vim.fn.expand('%:p')
  return M.is_in_prompts_folder(filepath)
end

function M.is_last_trackable(path)
  if not path then return false end
  return M.is_in_prompts_folder(path)
    or M.is_metaplan(path)
    or M.is_plan_file(path, 'idea')
    or M.is_plan_file(path, 'spec')
    or M.is_plan_file(path, 'masterplan')
end

return M

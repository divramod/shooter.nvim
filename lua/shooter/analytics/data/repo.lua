-- Repo identification + project filtering.
-- Pulled out of shooter/analytics/data.lua during plan 0001 phase 004 T007.
-- T008 down-payment: git remote URL fetched via vim.fn.system table-form.

local utils = require('shooter.utils')

local M = {}

-- Get git remote info for determining repo name.
function M.get_git_remote_info(filepath)
  local result
  if filepath then
    local dir = utils.dir_exists(filepath .. '/.git') and filepath or utils.get_dirname(filepath)
    result = vim.fn.system({ 'git', '-C', dir, 'remote', 'get-url', 'origin' })
  else
    result = vim.fn.system({ 'git', 'remote', 'get-url', 'origin' })
  end
  if not result or result == '' or vim.v.shell_error ~= 0 then return nil, nil end
  result = utils.trim(result)
  local user, repo = result:match('git@[^:]+:([^/]+)/(.+)%.git$')
  if user and repo then return user, repo end
  user, repo = result:match('https?://[^/]+/([^/]+)/(.+)%.git$')
  if user and repo then return user, repo end
  user, repo = result:match('git@[^:]+:([^/]+)/(.+)$')
  if user and repo then return user, repo end
  user, repo = result:match('https?://[^/]+/([^/]+)/(.+)$')
  return user, repo
end

function M.detect_project_from_path(filepath)
  if not filepath then return nil end
  return filepath:match('/projects/([^/]+)/')
end

function M.repo_matches_filter(repo_name, project_filter)
  if not project_filter or project_filter == '' then return true end
  if project_filter:find('/', 1, true) then
    return repo_name == project_filter
  end
  local short = repo_name:match('/([^/]+)$') or repo_name
  return short == project_filter
end

return M

-- Global / project context-file presence checks.
-- Pulled out of shooter/health.lua during plan 0001 phase 004 T006.

local M = {}

function M.check_global_context()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  local global_context_path = config.get('paths.global_context')
  if not global_context_path then
    vim.health.error('Config error: paths.global_context is nil')
    return false
  end

  local expanded_path = utils.expand_path(global_context_path)

  if not utils.file_exists(expanded_path) then
    vim.health.warn(
      string.format('Global context file not found: %s', global_context_path),
      {
        'Create the file to provide global context for all projects',
        string.format('mkdir -p %s', vim.fn.fnamemodify(expanded_path, ':h')),
        string.format('touch %s', expanded_path),
      }
    )
    return false
  end

  vim.health.ok(string.format('Global context file exists: %s', global_context_path))
  return true
end

function M.check_project_context()
  local config = require('shooter.config')
  local utils = require('shooter.utils')
  local files = require('shooter.core.files')

  local git_root = files.get_git_root()
  if not git_root then
    vim.health.info('Not in a git repository', {
      'Project context is scoped to git repositories',
    })
    return false
  end

  local project_context_path = config.get('paths.project_context')
  if not project_context_path then
    vim.health.error('Config error: paths.project_context is nil')
    return false
  end

  local full_path = git_root .. '/' .. project_context_path

  if not utils.file_exists(full_path) then
    vim.health.info(
      string.format('Project context file not found: %s', project_context_path),
      {
        'Create it to provide project-specific context',
        'Use the template at: templates/shooter-context-project-template.md',
      }
    )
    return false
  end

  vim.health.ok(string.format('Project context file exists: %s', project_context_path))
  return true
end

return M

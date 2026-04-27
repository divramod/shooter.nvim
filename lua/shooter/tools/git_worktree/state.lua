-- LAST-file state machine — read/write the .hal/git/worktree/LAST identifier.
-- Pulled out of shooter/tools/git_worktree.lua during plan 0001 phase 004 T007.
-- T008 down-payment: git operations use table-form vim.fn.system.

local repo = require('shooter.tools.git_worktree.repo')
local list = require('shooter.tools.git_worktree.list')

local M = {}

---@return string|nil
function M.get_repo_wt_state_dir()
  local main_path = list.get_main_worktree()
  if not main_path then return nil end
  return main_path .. '/.hal/git/worktree'
end

function M.ensure_gitignore()
  local state_dir = M.get_repo_wt_state_dir()
  if not state_dir then return end

  vim.fn.mkdir(state_dir, 'p')
  local gitignore_path = state_dir .. '/.gitignore'
  local needs_commit = false

  if vim.fn.filereadable(gitignore_path) == 1 then
    local content = vim.fn.readfile(gitignore_path)
    local has_last = false
    for _, line in ipairs(content) do
      if line == 'LAST' then has_last = true; break end
    end
    if not has_last then
      table.insert(content, 'LAST')
      vim.fn.writefile(content, gitignore_path)
      needs_commit = true
    end
  else
    vim.fn.writefile({ 'LAST' }, gitignore_path)
    needs_commit = true
  end

  if needs_commit then
    local main_path = list.get_main_worktree()
    if main_path then
      vim.fn.system({ 'git', '-C', main_path, 'add', gitignore_path })
      vim.fn.system({ 'git', '-C', main_path, 'commit', '-m',
        'chore(hal): add .hal/git/worktree/.gitignore' })
    end
  end
end

function M.save_last_worktree()
  local _, current_root = repo.get_repo_name()
  if not current_root then return end

  local state_dir = M.get_repo_wt_state_dir()
  if not state_dir then return end

  M.ensure_gitignore()

  local wt_prefix = repo.WORKTREE_BASE .. '/'
  local identifier
  if current_root:sub(1, #wt_prefix) == wt_prefix then
    local rest = current_root:sub(#wt_prefix + 1)
    identifier = rest:match('^[^/]+/(.+)$')
  else
    identifier = 'main'
  end

  if identifier then
    vim.fn.mkdir(state_dir, 'p')
    vim.fn.writefile({ identifier }, state_dir .. '/LAST')
  end
end

---@return string|nil
function M.read_last_worktree()
  local state_dir = M.get_repo_wt_state_dir()
  if not state_dir then return nil end

  local last_file = state_dir .. '/LAST'
  if vim.fn.filereadable(last_file) ~= 1 then return nil end

  local lines = vim.fn.readfile(last_file)
  if #lines > 0 and lines[1] ~= '' then
    return lines[1]
  end
  return nil
end

return M

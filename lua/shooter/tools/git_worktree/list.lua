-- Worktree listing — git worktree list + numbered-worktrees scanner.
-- Pulled out of shooter/tools/git_worktree.lua during plan 0001 phase 004 T007.

local repo = require('shooter.tools.git_worktree.repo')

local M = {}

---@return table[]
function M.get_worktrees()
  local lines = repo.git_cmd('git worktree list --porcelain')
  if not lines then return {} end
  local worktrees = {}
  local current = {}
  for _, line in ipairs(lines) do
    if line:match('^worktree ') then
      current = { path = line:match('^worktree (.+)') }
    elseif line:match('^branch ') then
      current.branch = line:match('^branch refs/heads/(.+)')
    elseif line == '' then
      if current.path then table.insert(worktrees, current) end
      current = {}
    elseif line:match('^bare') then
      current.bare = true
    end
  end
  if current.path then table.insert(worktrees, current) end
  return worktrees
end

---@return string|nil
function M.get_main_worktree()
  local worktrees = M.get_worktrees()
  if #worktrees > 0 then return worktrees[1].path end
  return nil
end

---@return table[]
function M.get_numbered_worktrees()
  local repo_name = repo.get_repo_name()
  if not repo_name then return {} end

  local repo_wt_dir = repo.WORKTREE_BASE .. '/' .. repo_name
  if vim.fn.isdirectory(repo_wt_dir) ~= 1 then return {} end

  local entries = vim.fn.readdir(repo_wt_dir)
  local numbered = {}
  for _, entry in ipairs(entries) do
    local full_path = repo_wt_dir .. '/' .. entry
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(numbered, { name = entry, path = full_path })
    end
  end
  table.sort(numbered, function(a, b) return a.name < b.name end)
  return numbered
end

return M

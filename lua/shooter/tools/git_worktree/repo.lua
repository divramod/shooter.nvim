-- Git introspection helpers (repo name resolution + git command runner).
-- Pulled out of shooter/tools/git_worktree.lua during plan 0001 phase 004 T007.
-- T008 down-payment: shell-outs use shellescape OR table-form when the user-controlled
-- arg can sit at the head of the argv vector (vim.fn.systemlist({...})).

local M = {}

M.WORKTREE_BASE = vim.fn.expand('~/.hal/git/worktree')

---@return string|nil repo_name, string|nil git_root
function M.get_repo_name()
  local git_root
  local result = vim.fn.systemlist({ 'git', 'rev-parse', '--show-toplevel' })
  if vim.v.shell_error == 0 and #result > 0 then
    git_root = result[1]
  else
    local buf_dir = vim.fn.expand('%:p:h')
    if buf_dir ~= '' then
      result = vim.fn.systemlist({ 'git', '-C', buf_dir, 'rev-parse', '--show-toplevel' })
      if vim.v.shell_error == 0 and #result > 0 then
        git_root = result[1]
      end
    end
  end
  if not git_root then return nil, nil end

  local wt_prefix = M.WORKTREE_BASE .. '/'
  if git_root:sub(1, #wt_prefix) == wt_prefix then
    local rest = git_root:sub(#wt_prefix + 1)
    local repo_name = rest:match('^([^/]+)/')
    if repo_name then
      return repo_name, git_root
    end
  end

  local name = vim.fn.fnamemodify(git_root, ':t')
  return name, git_root
end

-- Run a git command, trying cwd first then the current buffer's directory.
-- `cmd` is a string; we strip the leading "git " and dispatch via table-form.
---@param cmd string
---@return string[]|nil
function M.git_cmd(cmd)
  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error == 0 then
    return lines
  end
  local buf_dir = vim.fn.expand('%:p:h')
  if buf_dir ~= '' then
    local stripped = cmd:gsub('^git ', '')
    local args = { 'git', '-C', buf_dir }
    for word in stripped:gmatch('%S+') do table.insert(args, word) end
    lines = vim.fn.systemlist(args)
    if vim.v.shell_error == 0 then
      return lines
    end
  end
  return nil
end

---@return string|nil
function M.get_relative_file()
  local file = vim.fn.expand('%:p')
  if file == '' then return nil end
  local _, root = M.get_repo_name()
  if not root then return nil end
  if file:sub(1, #root) == root then
    return file:sub(#root + 2)
  end
  return nil
end

return M

-- Git-root probing for shotfile state.
-- get_git_root: always the MAIN worktree's toplevel (shotfiles are single-source on main).
-- get_cwd_git_root: the cwd's worktree toplevel (for non-shotfile ops).
-- get_file_git_root: the toplevel that owns a given file path (works across worktrees).

local M = {}

function M.get_git_root()
  local wt_lines = vim.fn.systemlist('git worktree list --porcelain')
  if vim.v.shell_error == 0 then
    for _, line in ipairs(wt_lines) do
      local path = line:match('^worktree (.+)')
      if path and path ~= '' then return path end
    end
  end
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #root > 0 then return root[1] end
  return nil
end

function M.get_cwd_git_root()
  local result = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end
  return nil
end

function M.get_file_git_root(filepath)
  if not filepath or filepath == '' then return nil end
  local dir = vim.fn.fnamemodify(filepath, ':h')
  if dir == '' or vim.fn.isdirectory(dir) ~= 1 then return nil end
  local result = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #result > 0 and result[1] ~= '' then
    return result[1]
  end
  return nil
end

return M

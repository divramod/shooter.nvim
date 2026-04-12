-- Git helpers for the .shooter folder.
-- Used by HalShooterGitPush: stages, commits, and pushes the .shooter/ tree.

local M = {}

local COMMIT_MSG = 'chore(shooter): sync'

local function git(git_root, ...)
  local cmd = { 'git', '-C', git_root }
  for _, a in ipairs({ ... }) do table.insert(cmd, a) end
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

-- Stage all .shooter/ changes and commit them with a fixed subject.
-- Returns: ok_bool, msg_or_nil, committed_bool
--   ok=true, committed=false → nothing to commit (no-op, msg explains)
--   ok=true, committed=true  → committed (msg nil)
--   ok=false                 → failure (msg = error)
function M.stage_and_commit(git_root)
  if not git_root or git_root == '' then
    return false, 'no git root', false
  end
  if vim.fn.isdirectory(git_root .. '/.shooter') ~= 1 then
    return false, '.shooter folder not found', false
  end

  -- -A picks up additions, modifications, and deletions under .shooter/
  local add_out, add_err = git(git_root, 'add', '-A', '--', '.shooter')
  if add_err ~= 0 then
    return false, 'git add failed: ' .. add_out:gsub('\n', ' '), false
  end

  -- Exit 0 from --quiet means no staged diff for the pathspec.
  local _, diff_err = git(git_root, 'diff', '--cached', '--quiet', '--', '.shooter')
  if diff_err == 0 then
    return true, '.shooter: nothing to commit', false
  end

  local commit_out, commit_err = git(git_root, 'commit', '-m', COMMIT_MSG, '--', '.shooter')
  if commit_err ~= 0 then
    return false, 'git commit failed: ' .. commit_out:gsub('\n', ' '), false
  end

  return true, nil, true
end

-- Push the current branch. Returns: ok_bool, msg_or_nil.
function M.push(git_root)
  if not git_root or git_root == '' then
    return false, 'no git root'
  end
  local out, err = git(git_root, 'push')
  if err ~= 0 then
    return false, 'git push failed: ' .. out:gsub('\n', ' ')
  end
  return true, nil
end

-- Composite: stage+commit, then push if something was committed.
-- Returns: ok_bool, msg_for_user
function M.run(git_root)
  local ok, msg, committed = M.stage_and_commit(git_root)
  if not ok then
    return false, msg
  end
  if not committed then
    return true, msg  -- 'nothing to commit'
  end

  local push_ok, push_msg = M.push(git_root)
  if not push_ok then
    return false, 'committed but ' .. push_msg
  end
  return true, '.shooter: committed & pushed'
end

return M

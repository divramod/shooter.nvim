-- Git helpers for the shotfiles tree (.hal/shooter/shotfiles).
-- Used by HalShooterGitPush: stages, commits, and pushes shotfile changes.

local M = {}

local TARGET_PATH = '.hal/shooter/shotfiles'
local COMMIT_MSG = 'chore(shotfiles): sync'

local function git(git_root, ...)
  local cmd = { 'git', '-C', git_root }
  for _, a in ipairs({ ... }) do table.insert(cmd, a) end
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

-- Stage all shotfile changes and commit them with a fixed subject.
-- Returns: ok_bool, msg_or_nil, committed_bool
--   ok=true, committed=false → nothing to commit (no-op, msg explains)
--   ok=true, committed=true  → committed (msg nil)
--   ok=false                 → failure (msg = error)
function M.stage_and_commit(git_root)
  if not git_root or git_root == '' then
    return false, 'no git root', false
  end
  if vim.fn.isdirectory(git_root .. '/' .. TARGET_PATH) ~= 1 then
    return false, TARGET_PATH .. ' folder not found', false
  end

  -- -A picks up additions, modifications, and deletions under the pathspec.
  local add_out, add_err = git(git_root, 'add', '-A', '--', TARGET_PATH)
  if add_err ~= 0 then
    return false, 'git add failed: ' .. add_out:gsub('\n', ' '), false
  end

  -- Exit 0 from --quiet means no staged diff for the pathspec.
  local _, diff_err = git(git_root, 'diff', '--cached', '--quiet', '--', TARGET_PATH)
  if diff_err == 0 then
    return true, 'shotfiles: nothing to commit', false
  end

  local commit_out, commit_err = git(git_root, 'commit', '-m', COMMIT_MSG, '--', TARGET_PATH)
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
  return true, 'shotfiles: committed & pushed'
end

return M

-- Git helpers for the shotfiles tree (.hal/util/shooter/shotfiles).
-- Used by HalShooterGitPush: stages, commits, and pushes shotfile changes.

local M = {}

local TARGET_PATH = '.hal/util/shooter/shotfiles'
local COMMIT_MSG = 'chore(shotfiles): sync'

local function git(git_root, ...)
  local cmd = { 'git', '-C', git_root }
  for _, a in ipairs({ ... }) do table.insert(cmd, a) end
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

-- Persist any modified buffers whose file lives under the shotfiles tree, so
-- git sees the latest content (incl. brand-new shotfiles) before staging.
-- Compares via realpath because vim resolves symlinks (e.g. /tmp → /private/tmp
-- on macOS) when opening buffers, while git_root keeps the unresolved path.
function M.flush_shotfile_buffers(git_root)
  if not git_root or git_root == '' then return end
  local prefix = (vim.uv.fs_realpath(git_root) or git_root)
    .. '/' .. TARGET_PATH .. '/'
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      local resolved = name ~= '' and (vim.uv.fs_realpath(name) or name) or ''
      if resolved ~= '' and resolved:sub(1, #prefix) == prefix then
        vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end)
      end
    end
  end
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

-- Composite: fix titles, stage+commit any shotfile changes, push if any commit landed.
-- Returns: ok_bool, msg_for_user
function M.run(git_root)
  M.flush_shotfile_buffers(git_root)
  local fix_titles = require('shooter.core.fix_titles')
  local stats = fix_titles.fix_all_titles(git_root)
  local title_committed = false
  if stats.fixed > 0 then
    local ok, err = fix_titles.commit_fixes(git_root, stats.changes)
    if not ok then
      return false, 'title fix commit failed: ' .. (err or 'unknown')
    end
    title_committed = true
  end

  local ok, msg, sync_committed = M.stage_and_commit(git_root)
  if not ok then
    return false, msg
  end

  if not title_committed and not sync_committed then
    return true, msg  -- 'nothing to commit'
  end

  local push_ok, push_msg = M.push(git_root)
  if not push_ok then
    return false, 'committed but ' .. push_msg
  end

  local parts = {}
  if title_committed then
    table.insert(parts, string.format('fixed %d title%s', stats.fixed, stats.fixed == 1 and '' or 's'))
  end
  if sync_committed then
    table.insert(parts, 'synced')
  end
  table.insert(parts, 'pushed')
  return true, 'shotfiles: ' .. table.concat(parts, ', ')
end

return M

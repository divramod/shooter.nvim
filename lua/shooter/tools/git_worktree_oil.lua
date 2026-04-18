-- Jump between git worktrees via oil.nvim without changing the cwd.
-- Used by HalShooterGitWorktreeOpenOil (<leader>gwd1..9).
--
-- Behaviour:
--   - Resolve the "current file" from the active buffer (or the cursor entry
--     if the buffer is an oil view).
--   - Compute its path relative to the current worktree root.
--   - Resolve the target worktree by number under ~/.hal/git/worktree/<repo>/.
--   - Open oil at the parallel folder in the target worktree; if the same
--     file exists, position the cursor on its basename. If the folder does
--     not exist, show a short notification.

local M = {}

local WORKTREE_BASE = vim.fn.expand('~/.hal/git/worktree')

local function notify(msg)
  vim.notify('[shooter] ' .. msg, vim.log.levels.INFO)
end

local function current_worktree_root()
  local buf_dir = vim.fn.expand('%:p:h')
  local cmd
  if buf_dir ~= '' and vim.fn.isdirectory(buf_dir) == 1 then
    cmd = 'git -C ' .. vim.fn.shellescape(buf_dir) .. ' rev-parse --show-toplevel'
  else
    cmd = 'git rev-parse --show-toplevel'
  end
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error == 0 and #out > 0 then return out[1] end
  return nil
end

local function repo_name_for_root(root)
  if not root then return nil end
  local prefix = WORKTREE_BASE .. '/'
  if root:sub(1, #prefix) == prefix then
    return root:sub(#prefix + 1):match('^([^/]+)/')
  end
  return vim.fn.fnamemodify(root, ':t')
end

-- Resolve the file path the command should "follow". Returns an absolute
-- file path or nil when no current file context exists. For oil buffers this
-- returns the entry under the cursor when one is present; otherwise the oil
-- directory itself.
function M.current_context()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname:match('^oil://') then
    local ok, oil = pcall(require, 'oil')
    if not ok then return nil, 'oil not available' end
    local dir = oil.get_current_dir()
    local entry = oil.get_cursor_entry()
    if entry and entry.type == 'file' and dir then
      return dir .. entry.name, nil
    end
    return dir, nil
  end
  if bufname ~= '' then
    return vim.fn.fnamemodify(bufname, ':p'), nil
  end
  return nil, 'no current file'
end

-- Resolve target worktree root by number under ~/.hal/git/worktree/<repo>/.
function M.resolve_target(number, current_root)
  local repo = repo_name_for_root(current_root)
  if not repo then return nil, 'could not determine repo name' end
  local target = WORKTREE_BASE .. '/' .. repo .. '/' .. tostring(number)
  if vim.fn.isdirectory(target) ~= 1 then
    return nil, 'worktree ' .. number .. ' not found (' .. target .. ')'
  end
  return target, nil
end

-- Compute target path inside the target worktree. Returns target_file (may
-- be a directory or file), target_dir (directory to open oil in), and a
-- boolean file_exists indicating whether the same file exists in target.
function M.compute_target(current_file, current_root, target_root)
  local prefix = current_root .. '/'
  if current_file:sub(1, #current_root) ~= current_root then
    return nil, nil, false, 'current path is outside current worktree'
  end
  -- Handle the root dir case (current_file == current_root).
  local rel
  if current_file == current_root then
    rel = ''
  elseif current_file:sub(1, #prefix) == prefix then
    rel = current_file:sub(#prefix + 1)
  else
    return nil, nil, false, 'current path is outside current worktree'
  end

  local target_file = rel == '' and target_root or (target_root .. '/' .. rel)
  local is_dir_current = vim.fn.isdirectory(current_file) == 1
  local target_dir
  if is_dir_current then
    target_dir = target_file
  else
    target_dir = vim.fn.fnamemodify(target_file, ':h')
  end

  local file_exists = (not is_dir_current) and vim.fn.filereadable(target_file) == 1
  return target_file, target_dir, file_exists, nil
end

-- Open oil at target_dir (without changing cwd) and position the cursor on
-- the given basename if it exists in the directory listing.
function M.open_oil_at(target_dir, cursor_basename)
  local ok, oil = pcall(require, 'oil')
  if not ok then return false, 'oil not available' end
  if vim.fn.isdirectory(target_dir) ~= 1 then
    return false, 'target folder does not exist: ' .. target_dir
  end

  -- oil.open does not change cwd.
  oil.open(target_dir)

  if cursor_basename and cursor_basename ~= '' then
    vim.schedule(function()
      local bufnr = vim.api.nvim_get_current_buf()
      if not vim.api.nvim_buf_get_name(bufnr):match('^oil://') then return end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local pat = vim.pesc(cursor_basename)
      for i, line in ipairs(lines) do
        if line:match(pat) then
          pcall(vim.api.nvim_win_set_cursor, 0, { i, 0 })
          return
        end
      end
    end)
  end
  return true, nil
end

-- Top-level entry point.
function M.open_in_worktree(number)
  local current_root = current_worktree_root()
  if not current_root then
    notify('not inside a git worktree')
    return
  end

  local current_file, ctx_err = M.current_context()
  if not current_file then
    notify(ctx_err or 'no current file')
    return
  end

  local target_root, err = M.resolve_target(number, current_root)
  if not target_root then
    notify(err)
    return
  end

  if target_root == current_root then
    notify('already in worktree ' .. number)
    return
  end

  local target_file, target_dir, file_exists, cerr = M.compute_target(
    current_file, current_root, target_root)
  if not target_file then
    notify(cerr or 'failed to compute target')
    return
  end

  if vim.fn.isdirectory(target_dir) ~= 1 then
    notify('folder does not exist in worktree ' .. number .. ': ' .. target_dir)
    return
  end

  local cursor_basename = nil
  if file_exists then
    cursor_basename = vim.fn.fnamemodify(target_file, ':t')
  end

  local ok, oerr = M.open_oil_at(target_dir, cursor_basename)
  if not ok then
    notify(oerr or 'oil open failed')
    return
  end

  if vim.fn.isdirectory(current_file) ~= 1 and not file_exists then
    notify('file does not exist in worktree ' .. number
      .. ' (opened folder)')
  end
end

return M

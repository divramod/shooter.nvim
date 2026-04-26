-- File + buffer + git helpers shared by metaplan sub-modules.

local util = require('shooter.plans.metaplan.util')

local M = {}

function M.read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local s = f:read('*a') or ''
  f:close()
  return s
end

function M.write_file(path, content)
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

-- Locate a loaded buffer for `path` (realpath-compared, since /tmp → /private/tmp
-- on macOS). Returns bufnr or nil.
function M.find_loaded_buf(path)
  local target = vim.uv.fs_realpath(path) or path
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' then
        local resolved = vim.uv.fs_realpath(name) or name
        if resolved == target then return buf end
      end
    end
  end
  return nil
end

-- Save-and-close any loaded buffer pointing at `path`, so a subsequent
-- rename/delete on disk doesn't collide with stale buffer state.
function M.close_buf_for(path)
  local bufnr = M.find_loaded_buf(path)
  if not bufnr then return end
  if vim.bo[bufnr].modified then
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Flush any modified buffers whose file lives under docs/plans/, so
-- `git add` sees the latest content the user actually typed. Creates
-- the parent directory first so a brand-new phase file writes successfully.
function M.flush_plans_buffers(git_root)
  local resolved_root = vim.uv.fs_realpath(git_root) or git_root
  local prefixes = {}
  for _, rel in ipairs(util.COMMIT_PATHS) do
    table.insert(prefixes, resolved_root .. '/' .. rel .. '/')
    if resolved_root ~= git_root then
      table.insert(prefixes, git_root .. '/' .. rel .. '/')
    end
  end
  local function under_plans(name)
    if name == '' then return false end
    for _, prefix in ipairs(prefixes) do
      if name:sub(1, #prefix) == prefix then return true end
    end
    local resolved = vim.uv.fs_realpath(name)
    if resolved and resolved ~= name then
      for _, prefix in ipairs(prefixes) do
        if resolved:sub(1, #prefix) == prefix then return true end
      end
    end
    return false
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      if under_plans(name) then
        local parent = vim.fn.fnamemodify(name, ':h')
        if parent ~= '' and vim.fn.isdirectory(parent) ~= 1 then
          vim.fn.mkdir(parent, 'p')
        end
        vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end)
      end
    end
  end
end

function M.git(git_root, args)
  local cmd = { 'git', '-C', git_root }
  for _, a in ipairs(args) do table.insert(cmd, a) end
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

-- git add + commit (no push) the plan folders. Only folders that actually
-- exist are included in the pathspec, so a repo with nothing plan-related
-- yet is a no-op rather than an error.
-- Returns: ok_bool, msg_or_nil, committed_bool
function M.commit_plans(git_root, message)
  if not git_root or git_root == '' then return false, 'no git root', false end
  message = message or util.COMMIT_MSG

  local present = {}
  for _, rel in ipairs(util.COMMIT_PATHS) do
    if vim.fn.isdirectory(git_root .. '/' .. rel) == 1 then
      table.insert(present, rel)
    end
  end
  if #present == 0 then
    return true, 'plans: no folders to commit', false
  end

  M.flush_plans_buffers(git_root)

  local add = { 'add', '-A', '--' }
  for _, p in ipairs(present) do table.insert(add, p) end
  local add_out, add_err = M.git(git_root, add)
  if add_err ~= 0 then
    return false, 'git add failed: ' .. add_out:gsub('\n', ' '), false
  end

  local changed = {}
  for _, p in ipairs(present) do
    local _, err = M.git(git_root, { 'diff', '--cached', '--quiet', '--', p })
    if err ~= 0 then table.insert(changed, p) end
  end
  if #changed == 0 then
    return true, 'plans: nothing to commit', false
  end

  local commit = { 'commit', '-m', message, '--' }
  for _, p in ipairs(changed) do table.insert(commit, p) end
  local commit_out, commit_err = M.git(git_root, commit)
  if commit_err ~= 0 then
    return false, 'git commit failed: ' .. commit_out:gsub('\n', ' '), false
  end
  return true, nil, true
end

return M

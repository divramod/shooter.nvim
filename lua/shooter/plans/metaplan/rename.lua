-- Plan rename: folder rename, metaplan-line rewrite, title-reference rewrite.
-- Path-traversal-sensitive — Phase 001 T005 hardens the regex/canonicalization.

local io_mod = require('shooter.plans.metaplan.io')
local parse = require('shooter.plans.metaplan.parse')
local meta = require('shooter.plans.metaplan.meta')

local M = {}

-- Replace the first markdown heading in `path` whose text contains `needle`
-- with `replacement` substituted in.
function M.replace_title_reference(path, needle, replacement)
  if vim.fn.filereadable(path) ~= 1 then return end
  local content = io_mod.read_file(path)
  if not content then return end
  local lines = vim.split(content, '\n', { plain = true })
  for i, line in ipairs(lines) do
    if line:match('^#[ \t]') then
      if line:find(needle, 1, true) then
        lines[i] = line:gsub(vim.pesc(needle), replacement, 1)
        io_mod.write_file(path, table.concat(lines, '\n'))
      end
      return
    end
  end
end

-- Locate the metaplan line whose plan reference matches `name` and replace
-- the name with `new_name`.
function M.rewrite_metaplan_line(git_root, old_name, new_name)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not old_name or old_name == '' then return false, 'no old name' end
  if not new_name or new_name == '' then return false, 'no new name' end
  local path = meta.get_path(git_root)
  local bufnr = io_mod.find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local content = io_mod.read_file(path)
    if not content then return false, 'metaplan not found' end
    lines = vim.split(content, '\n', { plain = true })
  end

  local found = false
  for i, line in ipairs(lines) do
    if line:match('^%-%s') and parse.extract_plan_name(line) == old_name then
      lines[i] = line:gsub(vim.pesc(old_name), new_name, 1)
      found = true
      break
    end
  end
  if not found then return false, 'plan not in metaplan: ' .. old_name end

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    if not io_mod.write_file(path, table.concat(lines, '\n')) then
      return false, 'cannot write ' .. path
    end
  end
  return true
end

-- Remove the first metaplan entry whose plan reference matches `name`,
-- along with its indented child notes.
function M.remove_metaplan_entry(git_root, name)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not name or name == '' then return false, 'no plan name' end
  local util = require('shooter.plans.metaplan.util')
  local path = meta.get_path(git_root)
  local bufnr = io_mod.find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local content = io_mod.read_file(path)
    if not content then return true end
    lines = vim.split(content, '\n', { plain = true })
  end

  local start_idx
  for i, line in ipairs(lines) do
    if line:match('^%-%s') and parse.extract_plan_name(line) == name then
      start_idx = i
      break
    end
  end
  if not start_idx then return true end

  local end_idx = start_idx
  for j = start_idx + 1, #lines do
    local nxt = lines[j]
    if util.is_header(nxt) or util.is_top_entry(nxt) or not util.is_child_line(nxt) then break end
    end_idx = j
  end
  while end_idx > start_idx and lines[end_idx] == '' do end_idx = end_idx - 1 end

  for _ = start_idx, end_idx do
    table.remove(lines, start_idx)
  end

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    if not io_mod.write_file(path, table.concat(lines, '\n')) then
      return false, 'cannot write ' .. path
    end
  end
  return true
end

-- Rename a plan's folder docs/plans/<old>/ → docs/plans/<new>/ in MAIN.
-- Internal helper used by fix() during gap-fill renumbering.
function M.rename_plan_folder(git_root, old_name, new_name)
  if old_name == new_name then return true, 'unchanged' end
  local plans_rel = 'docs/plans'
  local old_folder = git_root .. '/' .. plans_rel .. '/' .. old_name
  local new_folder = git_root .. '/' .. plans_rel .. '/' .. new_name
  if vim.fn.isdirectory(old_folder) ~= 1 then return true, 'no folder' end
  if vim.fn.isdirectory(new_folder) == 1 then
    return false, new_folder .. ' already exists'
  end

  local files = require('shooter.core.files')

  for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
    local bufnr = vim.fn.bufnr(old_folder .. '/' .. kind .. '.md')
    if bufnr and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
      if vim.bo[bufnr].modified then
        vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
      end
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  vim.fn.system({ 'git', '-C', git_root, 'mv',
    plans_rel .. '/' .. old_name, plans_rel .. '/' .. new_name })
  if vim.v.shell_error ~= 0 then
    if not os.rename(old_folder, new_folder) then
      return false, 'rename failed'
    end
  end

  for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
    local p = new_folder .. '/' .. kind .. '.md'
    if vim.fn.filereadable(p) == 1 then
      files.update_file_title(p, files.title_from_path(p))
    end
  end

  return true
end

-- Rename a plan in MAIN: rename folder + update titles + rewrite metaplan
-- line + commit. Worktrees are NOT touched.
function M.rename_plan(git_root, old_name, new_name)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not old_name or old_name == '' then return false, 'no old name' end
  if not new_name or new_name == '' then return false, 'no new name' end
  if old_name == new_name then return false, 'name unchanged' end
  -- Defense-in-depth: validate BOTH names. The NNNN-slug regex structurally
  -- rejects path-traversal (..), separators (/), and shell metacharacters.
  -- old_name is normally extracted from metaplan lines via the same regex,
  -- so this only matters for programmatic callers — but the cost is one
  -- pattern match.
  if not old_name:match('^%d%d%d%d%-[%l%d][%w%-]*$') then
    return false, 'invalid old plan name (need NNNN-slug)'
  end
  if not new_name:match('^%d%d%d%d%-[%l%d][%w%-]*$') then
    return false, 'invalid plan name (need NNNN-slug)'
  end

  local plans_rel = 'docs/plans'
  local old_folder = git_root .. '/' .. plans_rel .. '/' .. old_name
  local new_folder = git_root .. '/' .. plans_rel .. '/' .. new_name

  if vim.fn.isdirectory(new_folder) == 1 then
    return false, new_folder .. ' already exists'
  end

  for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
    io_mod.close_buf_for(old_folder .. '/' .. kind .. '.md')
  end

  if vim.fn.isdirectory(old_folder) == 1 then
    local _, err = io_mod.git(git_root, { 'mv',
      plans_rel .. '/' .. old_name, plans_rel .. '/' .. new_name })
    if err ~= 0 then
      if not os.rename(old_folder, new_folder) then
        return false, 'failed to rename ' .. old_folder
      end
    end
    local files = require('shooter.core.files')
    for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
      local p = new_folder .. '/' .. kind .. '.md'
      if vim.fn.filereadable(p) == 1 then
        M.replace_title_reference(p, old_name, new_name)
        files.update_file_title(p, files.title_from_path(p))
      end
    end
  end

  local ok, err = M.rewrite_metaplan_line(git_root, old_name, new_name)
  if not ok then return false, err end

  local cok, cmsg, committed = io_mod.commit_plans(git_root,
    'chore(plans): rename ' .. old_name .. ' -> ' .. new_name)
  if not cok then return false, cmsg end
  return true, committed and 'renamed' or 'renamed (nothing to commit)'
end

return M

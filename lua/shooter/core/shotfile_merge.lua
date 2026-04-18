-- Merge all shots from one shotfile into another and delete the source file.
-- Used by HalShooterShotfileMergeInto (<leader>fM).
--
-- Contract:
--   * Preserves target H1 (# title) at the top.
--   * Inserts the source shots immediately after the target prefix (before
--     the target's first shot), so merged shots appear "at the top".
--   * Reuses renumber.renumber_shots() to renumber the combined file.
--   * Removes the source file from disk and wipes its buffer.
--
-- The "at the top" placement matches the user's description; renumber will
-- later reorder and renumber deterministically (open shots above done shots).

local M = {}

local renumber = require('shooter.core.renumber')

-- Split file content into { prefix_lines, shot_lines }. The prefix is
-- everything before the first `## shot` (or `## x shot`) header. If there
-- is no such header, the whole file is treated as prefix and shot_lines is
-- empty.
local function split_prefix_shots(lines)
  local prefix = {}
  local shots = {}
  local found = false
  for _, line in ipairs(lines) do
    if not found and line:match('^##%s+x?%s*shot%s') then
      found = true
    end
    if found then
      table.insert(shots, line)
    else
      table.insert(prefix, line)
    end
  end
  return prefix, shots
end

-- Pure merge: given the contents of source and target as arrays of lines,
-- return the merged lines array. Source shots are inserted at the top of
-- the target's shot region (immediately after the target prefix).
function M.build_merged(source_lines, target_lines)
  local _, source_shots = split_prefix_shots(source_lines)
  local target_prefix, target_shots = split_prefix_shots(target_lines)

  local out = {}
  for _, line in ipairs(target_prefix) do table.insert(out, line) end

  -- Ensure exactly one blank line separates prefix from shots.
  if #out > 0 and out[#out] ~= '' then table.insert(out, '') end

  for _, line in ipairs(source_shots) do table.insert(out, line) end
  if #source_shots > 0 and #target_shots > 0 then
    if out[#out] ~= '' then table.insert(out, '') end
  end
  for _, line in ipairs(target_shots) do table.insert(out, line) end

  return out
end

local function read_lines(filepath)
  local f = io.open(filepath, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()
  local lines = {}
  for line in (content .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, line)
  end
  -- The above loop always ends with a trailing empty string from the final
  -- newline we added; drop it so lines match the file's actual row count.
  if #lines > 0 and lines[#lines] == '' then
    table.remove(lines, #lines)
  end
  return lines
end

local function write_lines(filepath, lines)
  local f = io.open(filepath, 'w')
  if not f then return false end
  for i, line in ipairs(lines) do
    f:write(line)
    if i < #lines then f:write('\n') end
  end
  f:write('\n')
  f:close()
  return true
end

-- Full operation: merge source into target on disk, reload the target
-- buffer, renumber it, delete the source file + buffer, and switch to the
-- target. Returns ok, msg.
function M.merge_into(source_path, target_path)
  if not source_path or source_path == '' then return false, 'no source' end
  if not target_path or target_path == '' then return false, 'no target' end
  if source_path == target_path then return false, 'source == target' end

  local source_lines = read_lines(source_path)
  if not source_lines then return false, 'cannot read source' end
  local target_lines = read_lines(target_path)
  if not target_lines then return false, 'cannot read target' end

  local merged = M.build_merged(source_lines, target_lines)
  if not write_lines(target_path, merged) then
    return false, 'failed to write target'
  end

  -- Wipe source buffer if currently loaded.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name == source_path then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end

  -- Delete source file from disk.
  vim.fn.delete(source_path)

  -- Open target and renumber it.
  vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
  local bufnr = vim.api.nvim_get_current_buf()
  renumber.renumber_shots(bufnr)

  return true, 'merged ' .. vim.fn.fnamemodify(source_path, ':t')
    .. ' into ' .. vim.fn.fnamemodify(target_path, ':t')
end

return M

-- Comprehensive shotfile cleanup: title, empty-shot removal, renumber, commit.
-- Used by HalShooterShotfileFix (<leader>fff).

local utils = require('shooter.utils')
local files = require('shooter.core.files')
local fix_titles = require('shooter.core.fix_titles')
local renumber = require('shooter.core.renumber')
local config = require('shooter.config')

local M = {}

local function is_fence(line)
  if not line or not line:match('^%s*```') then return false end
  local _, count = line:gsub('```', '')
  return count == 1
end

-- True if header line has nothing after the shot number except optional
-- trailing whitespace and/or a single parenthesised timestamp.
function M.header_has_no_title(line)
  local rest = line:gsub('^##%s+x?%s*shot%s+%-?%d+%.%d+', '', 1)
  if rest == line then rest = line:gsub('^##%s+x?%s*shot%s+%-?%d+', '', 1) end
  if rest == line then rest = line:gsub('^##%s+x?%s*shot%s+%?', '', 1) end
  if rest == line then return false end
  rest = rest:gsub('%s*%b()%s*$', '')
  return rest:match('^%s*$') ~= nil
end

local function find_shot_ranges(lines)
  local shot_pat = config.get('patterns.shot_header')
  local ranges = {}
  local n = #lines
  local in_fence = false
  local fence_at = {}
  for i = 1, n do
    fence_at[i] = in_fence
    if is_fence(lines[i]) then in_fence = not in_fence end
  end

  local i = 1
  while i <= n do
    if not fence_at[i] and lines[i]:match(shot_pat) then
      local end_i = n
      for j = i + 1, n do
        if not fence_at[j] and lines[j]:match(shot_pat) then
          end_i = j - 1
          break
        end
      end
      table.insert(ranges, { start_i = i, end_i = end_i })
      i = end_i + 1
    else
      i = i + 1
    end
  end
  return ranges
end

-- Collapse blank lines directly above each ## shot header to exactly one.
-- Respects fenced code blocks. Does not touch the very first line of the file.
function M.normalize_blank_lines(lines)
  local shot_pat = config.get('patterns.shot_header')
  local n = #lines
  local in_fence = false
  local fence_at = {}
  for i = 1, n do
    fence_at[i] = in_fence
    if is_fence(lines[i]) then in_fence = not in_fence end
  end

  local drop = {}
  for i = 1, n do
    if not fence_at[i] and lines[i]:match(shot_pat) then
      -- Count contiguous blanks directly above.
      local blanks = 0
      local k = i - 1
      while k >= 1 and lines[k] == '' do
        blanks = blanks + 1
        k = k - 1
      end
      -- If there's any content above, keep exactly one blank; drop the rest.
      if k >= 1 and blanks > 1 then
        for d = k + 1, i - 2 do drop[d] = true end
      end
    end
  end

  local has_drop = false
  for _ in pairs(drop) do has_drop = true; break end
  if not has_drop then return lines end

  local out = {}
  for i = 1, n do
    if not drop[i] then table.insert(out, lines[i]) end
  end
  return out
end

-- Strip trailing whitespace-only lines from the end of the buffer so the
-- file never ends on an empty line.
function M.strip_trailing_blanks(lines)
  local n = #lines
  while n > 0 and lines[n]:match('^%s*$') do
    n = n - 1
  end
  if n == #lines then return lines end
  local out = {}
  for i = 1, n do out[i] = lines[i] end
  return out
end

-- Remove open empty shots. "Empty" = open (not executed), no title text in
-- the header, and no non-blank body lines. Returns { new_lines, removed }.
function M.strip_empty_shots(lines)
  local exec_pat = config.get('patterns.executed_shot_header')
  local ranges = find_shot_ranges(lines)
  local drop = {}
  local removed = 0

  for _, r in ipairs(ranges) do
    local header = lines[r.start_i]
    local is_done = header:match(exec_pat) ~= nil
    if not is_done and M.header_has_no_title(header) then
      local empty_body = true
      for k = r.start_i + 1, r.end_i do
        if lines[k]:match('%S') then empty_body = false; break end
      end
      if empty_body then
        for k = r.start_i, r.end_i do drop[k] = true end
        removed = removed + 1
      end
    end
  end

  if removed == 0 then return lines, 0 end

  local out = {}
  for k = 1, #lines do
    if not drop[k] then table.insert(out, lines[k]) end
  end
  return out, removed
end

-- Fix a single shotfile buffer: strip empties, renumber (which normalizes
-- blank lines above ## shot headers), fix H1 title on disk, reload buffer.
-- Returns: { title_fixed, removed, renumbered }
function M.fix_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local stats = { title_fixed = false, removed = 0, renumbered = 0 }

  local total = utils.buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, total)
  local new_lines, removed = M.strip_empty_shots(lines)
  if removed > 0 then
    utils.set_buf_lines(bufnr, 0, total, new_lines)
    stats.removed = removed
  end

  stats.renumbered = renumber.renumber_shots(bufnr)

  -- Normalize blank lines above each ## shot header to exactly one,
  -- and strip any trailing blank/whitespace-only lines at end of file.
  local total2 = utils.buf_line_count(bufnr)
  local lines2 = utils.get_buf_lines(bufnr, 0, total2)
  local normalized = M.normalize_blank_lines(lines2)
  normalized = M.strip_trailing_blanks(normalized)
  utils.set_buf_lines(bufnr, 0, total2, normalized)

  if filepath ~= '' and vim.fn.filereadable(filepath) == 1 then
    if vim.bo[bufnr].modified then
      vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
    end
    local changed = fix_titles.fix_title_in_file(filepath)
    if changed then
      stats.title_fixed = true
      vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! edit!') end)
    end
  end

  return stats
end

function M.build_commit_message(rel_path, stats)
  local parts = {}
  if stats.title_fixed then table.insert(parts, 'title') end
  if stats.removed > 0 then
    table.insert(parts, string.format('%d empty shot%s', stats.removed,
      stats.removed == 1 and '' or 's'))
  end
  table.insert(parts, 'renumber')
  return string.format('fix(shotfiles): cleanup %s (%s)\n',
    rel_path, table.concat(parts, ', '))
end

-- Stage and commit a single shotfile. Returns ok, msg, committed.
function M.commit(git_root, filepath, stats)
  local rel = filepath
  if filepath:sub(1, #git_root + 1) == git_root .. '/' then
    rel = filepath:sub(#git_root + 2)
  end

  local add_out = vim.fn.system({ 'git', '-C', git_root, 'add', '--', rel })
  if vim.v.shell_error ~= 0 then
    return false, 'git add failed: ' .. (add_out or ''):gsub('\n', ' '), false
  end

  vim.fn.system({ 'git', '-C', git_root, 'diff', '--cached', '--quiet', '--', rel })
  if vim.v.shell_error == 0 then
    return true, nil, false
  end

  local msg = M.build_commit_message(rel, stats)
  local commit_out = vim.fn.system({ 'git', '-C', git_root, 'commit', '-m', msg, '--', rel })
  if vim.v.shell_error ~= 0 then
    return false, 'git commit failed: ' .. (commit_out or ''):gsub('\n', ' '), false
  end
  return true, nil, true
end

-- Fix a single shotfile on disk (no buffer required).
-- Reads from disk, applies all fixes, writes back.
-- Returns stats table like fix_buffer.
function M.fix_file(filepath)
  local content, read_err = utils.read_file(filepath)
  if not content then return { title_fixed = false, removed = 0, renumbered = 0, error = read_err } end

  local lines = vim.split(content, '\n', { plain = true })
  local new_lines, removed = M.strip_empty_shots(lines)
  new_lines = M.normalize_blank_lines(new_lines)
  new_lines = M.strip_trailing_blanks(new_lines)

  utils.write_file(filepath, table.concat(new_lines, '\n'))

  local changed = fix_titles.fix_title_in_file(filepath)

  return { title_fixed = changed or false, removed = removed, renumbered = 0 }
end

-- Fix ALL shotfiles in the repo and commit in one go. Returns ok, msg.
function M.run_all()
  local git_root = files.get_git_root()
  if not git_root then return false, 'not in a git repo' end

  local all_paths = fix_titles.collect_shotfiles(git_root)
  if #all_paths == 0 then return true, 'no shotfiles found' end

  local total_fixed = 0
  local total_removed = 0
  local changed_paths = {}

  for _, filepath in ipairs(all_paths) do
    local stats = M.fix_file(filepath)
    if stats.title_fixed or stats.removed > 0 then
      total_fixed = total_fixed + 1
      table.insert(changed_paths, filepath)
    end
    total_removed = total_removed + stats.removed
  end

  local shotfiles_path = 'docs/shotfiles'
  vim.fn.system({ 'git', '-C', git_root, 'add', '-A', '--', shotfiles_path })

  vim.fn.system({ 'git', '-C', git_root, 'diff', '--cached', '--quiet', '--', shotfiles_path })
  if vim.v.shell_error == 0 then
    return true, string.format('shotfiles fix: %d checked, nothing to commit', #all_paths)
  end

  local parts = {}
  if total_fixed > 0 then
    table.insert(parts, string.format('%d fixed', total_fixed))
  end
  if total_removed > 0 then
    table.insert(parts, string.format('%d empty shots removed', total_removed))
  end
  table.insert(parts, 'synced')
  local msg = string.format('fix(shotfiles): cleanup (%s)', table.concat(parts, ', '))
  local commit_out = vim.fn.system({ 'git', '-C', git_root, 'commit', '-m', msg, '--', shotfiles_path })
  if vim.v.shell_error ~= 0 then
    return false, 'git commit failed: ' .. (commit_out or ''):gsub('\n', ' ')
  end

  return true, string.format('shotfiles fix: %s', table.concat(parts, ', '))
end

-- Top-level: fix current shotfile buffer and commit. Returns ok, msg.
function M.run(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then return false, 'buffer has no file' end

  local stats = M.fix_buffer(bufnr)

  local git_root = files.get_git_root()
  if git_root then
    local ok, err = M.commit(git_root, filepath, stats)
    if not ok then return false, err end
  end

  local bits = {}
  if stats.title_fixed then table.insert(bits, 'title fixed') end
  if stats.removed > 0 then
    table.insert(bits, string.format('%d empty removed', stats.removed))
  end
  if stats.renumbered > 0 then
    table.insert(bits, string.format('%d shots renumbered', stats.renumbered))
  end
  if #bits == 0 then bits = { 'nothing to fix' } end
  return true, 'shotfile fix: ' .. table.concat(bits, ', ')
end

return M

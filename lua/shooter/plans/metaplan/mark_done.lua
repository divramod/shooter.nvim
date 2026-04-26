-- mark_done: move a plan entry to ## done with a timestamp.

local util = require('shooter.plans.metaplan.util')
local io_mod = require('shooter.plans.metaplan.io')
local meta = require('shooter.plans.metaplan.meta')

local M = {}

function M.mark_done(git_root, lnum)
  if not git_root or git_root == '' then return false, 'no git root' end
  local path = meta.get_path(git_root)
  local bufnr = io_mod.find_loaded_buf(path)

  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local content = io_mod.read_file(path)
    if not content then return false, 'file not found' end
    lines = vim.split(content, '\n', { plain = true })
  end

  local line = lines[lnum]
  if not line then return false, 'no line at cursor' end
  local entry = line and line:match('^%-%s+(.-)%s*$')
  if not entry or entry == '' then
    return false, 'cursor not on a plan entry'
  end

  local in_done = false
  for i = 1, lnum - 1 do
    local h2 = lines[i] and lines[i]:match('^##%s+(.-)%s*$')
    if h2 then in_done = (h2:lower() == 'done') end
  end
  if in_done then return false, 'already in done' end

  local end_at = lnum
  for j = lnum + 1, #lines do
    local nxt = lines[j]
    if util.is_header(nxt) or util.is_top_entry(nxt) or not util.is_child_line(nxt) then break end
    end_at = j
  end
  while end_at > lnum and lines[end_at] == '' do end_at = end_at - 1 end

  local children = {}
  for j = lnum + 1, end_at do table.insert(children, lines[j]) end
  for _ = lnum, end_at do table.remove(lines, lnum) end

  local done_idx
  for i, l in ipairs(lines) do
    if l:match('^##%s+[Dd]one%s*$') then done_idx = i; break end
  end

  local body = entry:gsub(util.TIMESTAMP_TAIL, '')
  local stamped = string.format('- %s (%s)', body,
    os.date('%Y-%m-%d %H:%M:%S'))
  local block = { stamped }
  for _, c in ipairs(children) do table.insert(block, c) end

  if done_idx then
    for k = #block, 1, -1 do
      table.insert(lines, done_idx + 1, block[k])
    end
  else
    if #lines > 0 and lines[#lines] ~= '' then table.insert(lines, '') end
    table.insert(lines, '## done')
    for _, l in ipairs(block) do table.insert(lines, l) end
  end

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    if not io_mod.write_file(path, table.concat(lines, '\n')) then
      return false, 'cannot write'
    end
  end
  return true
end

return M

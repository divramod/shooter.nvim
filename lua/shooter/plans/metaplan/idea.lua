-- Plan-idea ops + new-plan creation.
-- idea.md is the per-plan shotfile; this module ensures it exists and
-- appends user-supplied (paren) extras + child notes from metaplan entries.

local util = require('shooter.plans.metaplan.util')
local io_mod = require('shooter.plans.metaplan.io')
local parse = require('shooter.plans.metaplan.parse')
local meta = require('shooter.plans.metaplan.meta')
local numbering = require('shooter.plans.metaplan.numbering')

local M = {}

-- Make sure docs/plans/<plan_name>/idea.md exists, creating the plan folder
-- and a title-only stub file when missing.
function M.ensure_plan_idea(git_root, plan_name)
  if not git_root or not plan_name or plan_name == '' then
    return false, 'no git_root/plan_name'
  end
  local files = require('shooter.core.files')
  local target = meta.idea_path(git_root, plan_name)

  if vim.fn.filereadable(target) == 1 then
    files.update_file_title(target, files.title_from_path(target))
    return true, 'exists'
  end

  vim.fn.mkdir(git_root .. '/docs/plans/' .. plan_name, 'p')
  local title = files.title_from_path(target)
  local f = io.open(target, 'w')
  if not f then return false, 'cannot create ' .. target end
  f:write('# ' .. title .. '\n\n')
  f:close()
  return true, 'created'
end

-- Inject user's description-paren + child notes into idea.md. If the topmost
-- shot is open, append to its body; otherwise insert a new `## shot K`
-- section (K = max + 1) above the topmost existing shot, or at the top
-- when the file has no shots yet.
function M.apply_extras_to_idea(git_root, plan_name, paren_text, note_lines)
  if not git_root or git_root == '' then return false end
  if not plan_name or plan_name == '' then return false end
  note_lines = note_lines or {}
  local has_paren = paren_text and paren_text ~= ''
  if not has_paren and #note_lines == 0 then return true end

  local ok = M.ensure_plan_idea(git_root, plan_name)
  if not ok then return false end

  local path = meta.idea_path(git_root, plan_name)
  local bufnr = io_mod.find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    lines = vim.split(io_mod.read_file(path) or '', '\n', { plain = true })
  end

  local first_shot_line, first_shot_open
  local max_n = 0
  for i, line in ipairs(lines) do
    local n = line:match(util.SHOT_HEADER)
    if n then
      n = tonumber(n)
      if n and n > max_n then max_n = n end
      if not first_shot_line then
        first_shot_line = i
        first_shot_open = line:match(util.OPEN_SHOT_HEADER) ~= nil
      end
    end
  end

  local bullets = {}
  if has_paren then table.insert(bullets, '- ' .. paren_text) end
  for _, n in ipairs(note_lines) do
    if n:match('^%-%s+') or n:match('^%s+%-%s+') then
      table.insert(bullets, n)
    else
      table.insert(bullets, '- ' .. n)
    end
  end

  if first_shot_line and first_shot_open then
    local shot_end = #lines
    for j = first_shot_line + 1, #lines do
      if lines[j]:match(util.SHOT_HEADER) then shot_end = j - 1; break end
    end
    while shot_end > first_shot_line and lines[shot_end] == '' do
      shot_end = shot_end - 1
    end
    for k = #bullets, 1, -1 do
      table.insert(lines, shot_end + 1, bullets[k])
    end
  else
    local new_n = max_n + 1
    local block = { '## shot ' .. new_n }
    for _, b in ipairs(bullets) do table.insert(block, b) end
    table.insert(block, '')

    if first_shot_line then
      local insert_at = first_shot_line
      while insert_at > 1 and lines[insert_at - 1] == '' do
        insert_at = insert_at - 1
      end
      for k = #block, 1, -1 do
        table.insert(lines, insert_at, block[k])
      end
      if lines[insert_at + #block] ~= '' then
        table.insert(lines, insert_at + #block, '')
      end
    else
      local insert_at = 1
      if lines[1] and lines[1]:match('^#%s') then
        insert_at = 2
        while lines[insert_at] == '' do insert_at = insert_at + 1 end
      end
      if insert_at > 1 and lines[insert_at - 1] ~= '' then
        table.insert(lines, insert_at, '')
        insert_at = insert_at + 1
      end
      for k = #block, 1, -1 do
        table.insert(lines, insert_at, block[k])
      end
    end
  end

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    io_mod.write_file(path, table.concat(lines, '\n'))
  end
  return true
end

-- Append `- <plan_name>` under `## next plans` in metaplan.md.
function M.append_to_next_plans(git_root, plan_name)
  local path = meta.get_path(git_root)
  local bufnr = io_mod.find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    lines = vim.split(io_mod.read_file(path) or '', '\n', { plain = true })
  end

  local in_section = false
  for _, line in ipairs(lines) do
    local h2 = line:match('^##%s+(.-)%s*$')
    if h2 then in_section = (h2:lower() == 'next plans') end
    if in_section and line:match('^%-%s+' .. vim.pesc(plan_name) .. '%s*$') then
      return
    end
  end

  local np_start, np_end
  for i, line in ipairs(lines) do
    if line:match('^##%s+next plans%s*$') then np_start = i
    elseif np_start and not np_end and line:match('^##%s') then np_end = i - 1 end
  end

  if not np_start then
    if #lines > 0 and lines[#lines] ~= '' then table.insert(lines, '') end
    table.insert(lines, '## next plans')
    np_start = #lines
    np_end = #lines
  end
  if not np_end then np_end = #lines end
  local insert_at = np_end + 1
  while insert_at > np_start + 1 and (lines[insert_at - 1] == nil or lines[insert_at - 1] == '') do
    insert_at = insert_at - 1
  end
  table.insert(lines, insert_at, '- ' .. plan_name)

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    io_mod.write_file(path, table.concat(lines, '\n'))
  end
end

-- Create a new docs/plans/<NNNN-slug>/plan.md, add the plan to the metaplan
-- under `## next plans`, and run fix() to reconcile everything.
function M.new_plan(git_root, title)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not title or title:match('^%s*$') then return false, 'empty title' end
  local slug = parse.slugify(title)
  if slug == '' then return false, 'invalid title' end

  local parsed = parse.parse(io_mod.read_file(meta.get_path(git_root)) or '')
  local plan_name = string.format('%04d-%s',
    numbering.next_free_plan_number(git_root, parsed.sections), slug)

  local plan_dir = git_root .. '/docs/plans/' .. plan_name
  vim.fn.mkdir(plan_dir, 'p')
  local path = plan_dir .. '/plan.md'
  if not io_mod.write_file(path, '# ' .. plan_name .. '\n\n') then
    return false, 'cannot write ' .. path
  end
  M.ensure_plan_idea(git_root, plan_name)

  M.append_to_next_plans(git_root, plan_name)
  -- Lazy-require fix to break the cycle (fix → idea → fix on new_plan).
  local fix = require('shooter.plans.metaplan.fix')
  fix.fix(git_root)
  return true, path
end

return M

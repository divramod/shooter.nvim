-- Masterplan file helpers: parse / fix / mark_done for docs/plans/masterplan.md.
-- The fix pass normalizes title, canonical section order, slug + sequential
-- numbering in `## next plans`, and trims excess blank lines. Content after
-- the first `(` on an entry line is preserved verbatim, and indented child
-- lines (notes/subnotes) travel with their parent entry.

local M = {}

local SECTIONS = { 'in progress', 'next plans', 'backlog', 'done' }
local TIMESTAMP_TAIL = '%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)$'

function M.get_path(git_root)
  return git_root .. '/docs/plans/masterplan.md'
end

function M.get_alias(git_root)
  local f = io.open(git_root .. '/.hal/ALIAS', 'r')
  if not f then return nil end
  local s = f:read('*a') or ''
  f:close()
  s = s:match('^%s*(.-)%s*$')
  if s == '' then return nil end
  return s
end

function M.get_title(git_root)
  local repo = vim.fn.fnamemodify(git_root, ':t')
  local alias = M.get_alias(git_root)
  if alias then
    return string.format('# masterplan %s (%s)', repo, alias)
  end
  return string.format('# masterplan %s', repo)
end

-- Slugify: lowercase, collapse non-alphanumeric runs to single '-', trim.
function M.slugify(text)
  local s = (text or ''):lower():gsub('[^a-z0-9]+', '-')
  return (s:gsub('^%-+', ''):gsub('%-+$', ''))
end

-- Strip a leading NNNN- or ????- prefix from the text before slugifying.
local function strip_prefix(text)
  local rest = text:match('^%d%d%d%d%-(.*)$')
  if rest then return rest end
  rest = text:match('^%?%?%?%?%-(.*)$')
  if rest then return rest end
  return text
end

-- Split an entry text into `name_part` (pre-`(`, for slugifying) and
-- `rest` (from the first `(` to end, kept verbatim). No `(` → rest = "".
local function split_at_parens(text)
  local name, rest = text:match('^(.-)%s*(%b()%s*.*)$')
  if name and rest and rest ~= '' then
    return name, rest
  end
  -- Fall back: unbalanced `(...` — split at first `(` as best-effort.
  local idx = text:find('(', 1, true)
  if idx then
    return text:sub(1, idx - 1):match('^(.-)%s*$'), text:sub(idx)
  end
  return text, ''
end

local function is_top_entry(line)   return line:match('^%-%s+') ~= nil end
local function is_header(line)      return line:match('^##%s') ~= nil end
local function is_child_line(line)
  -- blank lines or indented lines are candidate children of the previous entry
  return line == '' or line:match('^%s')
end

-- Parse content into { sections = {name → { {text, children}, ... }}, order = {...} }.
-- `text` is the entry without leading "- ". `children` is a list of raw
-- following lines (indented notes, blank separators) up to the next top-level
-- entry or section header; trailing blanks are trimmed.
function M.parse(content)
  local parsed = { sections = {}, order = {} }
  local lines = vim.split(content or '', '\n', { plain = true })
  local current = nil
  local i = 1
  while i <= #lines do
    local raw = lines[i]
    local h2 = raw:match('^##%s+(.-)%s*$')
    if h2 then
      current = h2:lower()
      if not parsed.sections[current] then
        parsed.sections[current] = {}
        table.insert(parsed.order, current)
      end
      i = i + 1
    elseif current and is_top_entry(raw) then
      local text = raw:match('^%-%s+(.-)%s*$')
      local children = {}
      local j = i + 1
      while j <= #lines do
        local nxt = lines[j]
        if is_header(nxt) or is_top_entry(nxt) then break end
        if not is_child_line(nxt) then break end
        table.insert(children, nxt)
        j = j + 1
      end
      while #children > 0 and children[#children] == '' do
        table.remove(children)
      end
      table.insert(parsed.sections[current], { text = text, children = children })
      i = j
    else
      i = i + 1
    end
  end
  return parsed
end

local function is_canonical(name)
  for _, s in ipairs(SECTIONS) do if s == name then return true end end
  return false
end

local function render_entry(entry, out)
  table.insert(out, '- ' .. entry.text)
  for _, child in ipairs(entry.children or {}) do
    table.insert(out, child)
  end
end

-- Names currently listed in `## next plans` (set of "NNNN-slug" strings).
-- Used to exclude docs/plans folders that correspond to not-yet-started plans
-- from the max-number calculation.
local function next_plan_names(sections)
  local set = {}
  for _, entry in ipairs((sections or {})['next plans'] or {}) do
    local name = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
    if name then set[name] = true end
  end
  return set
end

-- Highest plan number that counts as "already used" — i.e. plans that are in
-- progress / backlog / done or have a docs/plans/ folder that is NOT merely a
-- placeholder for a `## next plans` entry. Used by fix() to pick the starting
-- number for next-plans renumbering so it never collides with a started plan,
-- yet also doesn't bump itself upward on every run.
function M.max_plan_number(git_root, sections)
  local max = 0
  local function bump(n) if n and n > max then max = n end end

  local next_set = next_plan_names(sections)
  local plans_dir = git_root and (git_root .. '/docs/plans') or nil
  if plans_dir and vim.fn.isdirectory(plans_dir) == 1 then
    for _, name in ipairs(vim.fn.readdir(plans_dir)) do
      local pname = name:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
      if pname and not next_set[pname] then
        bump(tonumber(pname:match('^(%d%d%d%d)%-')))
      end
    end
  end

  sections = sections or {}
  for _, sect in ipairs({ 'in progress', 'backlog', 'done' }) do
    for _, entry in ipairs(sections[sect] or {}) do
      bump(tonumber(entry.text:match('^(%d%d%d%d)%-')))
    end
  end
  return max
end

-- Next free plan number across EVERYTHING (docs/plans folders + every
-- masterplan section, including `## next plans`). Used by new_plan to pick a
-- number that won't collide with anything currently in the system.
function M.next_free_plan_number(git_root, sections)
  local max = 0
  local function bump(n) if n and n > max then max = n end end

  local plans_dir = git_root and (git_root .. '/docs/plans') or nil
  if plans_dir and vim.fn.isdirectory(plans_dir) == 1 then
    for _, name in ipairs(vim.fn.readdir(plans_dir)) do
      bump(tonumber(name:match('^(%d%d%d%d)%-')))
    end
  end

  sections = sections or {}
  for _, sect in ipairs(SECTIONS) do
    for _, entry in ipairs(sections[sect] or {}) do
      bump(tonumber(entry.text:match('^(%d%d%d%d)%-')))
    end
  end
  return max + 1
end

-- Render parsed + title back to canonical masterplan content.
-- `## next plans` entries are renumbered sequentially. The starting number is
-- opts.start_number when provided; otherwise falls back to the first entry's
-- NNNN- prefix (or 1). The pre-paren portion is slugified; anything from the
-- first `(` onwards plus child notes is preserved verbatim.
function M.render(parsed, title, opts)
  opts = opts or {}
  local sections = parsed.sections

  local next_plans = sections['next plans'] or {}
  if #next_plans > 0 then
    local start = opts.start_number
      or tonumber(next_plans[1].text:match('^(%d%d%d%d)%-'))
      or 1
    for i, entry in ipairs(next_plans) do
      local stripped = strip_prefix(entry.text)
      local name, rest = split_at_parens(stripped)
      local slug = M.slugify(name)
      if slug == '' then slug = 'plan' end
      if rest ~= '' then
        entry.text = string.format('%04d-%s %s', start + i - 1, slug, rest)
      else
        entry.text = string.format('%04d-%s', start + i - 1, slug)
      end
    end
  end

  local out = { title, '' }
  for _, name in ipairs(SECTIONS) do
    table.insert(out, '## ' .. name)
    for _, entry in ipairs(sections[name] or {}) do
      render_entry(entry, out)
    end
    table.insert(out, '')
  end
  for _, name in ipairs(parsed.order) do
    if not is_canonical(name) then
      table.insert(out, '## ' .. name)
      for _, entry in ipairs(sections[name] or {}) do
        render_entry(entry, out)
      end
      table.insert(out, '')
    end
  end

  while #out > 0 and out[#out] == '' do table.remove(out) end
  return table.concat(out, '\n') .. '\n'
end

-- Locate a loaded buffer for `path` (realpath-compared, since /tmp → /private/tmp
-- on macOS). Returns bufnr or nil.
local function find_loaded_buf(path)
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

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local s = f:read('*a') or ''
  f:close()
  return s
end

local function write_file(path, content)
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

-- Reconcile the shotfile for a single plan under
-- .hal/util/shooter/shotfiles/docs/plans: rename on number drift, create if absent,
-- and keep the `# <path>` title in sync. Idempotent. Returns ok_bool, action.
function M.ensure_plan_shotfile(git_root, plan_name)
  local files = require('shooter.core.files')
  local action, target, old_path = M.resolve_plan_file(git_root, plan_name)
  if not action then return false, target end  -- target holds error string

  if action == 'exists' then
    files.update_file_title(target, files.title_from_path(target))
    return true, 'exists'
  end

  if action == 'rename' then
    local rename = require('shooter.core.rename')
    local bufnr = vim.fn.bufnr(old_path)
    if bufnr and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
      if vim.bo[bufnr].modified then
        vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
      end
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    local ok, err = rename.perform_rename(old_path, plan_name .. '.md')
    if not ok then return false, err or 'rename failed' end
    files.update_file_title(target, files.title_from_path(target))
    return true, 'renamed'
  end

  -- action == 'new'
  vim.fn.mkdir(git_root .. '/.hal/util/shooter/shotfiles/docs/plans', 'p')
  local title = files.title_from_path(target)
  local f = io.open(target, 'w')
  if not f then return false, 'cannot create ' .. target end
  f:write('# ' .. title .. '\n\n')
  f:close()
  return true, 'created'
end

-- Append `- <plan_name>` under `## next plans` in masterplan.md. If the
-- masterplan file or the section is missing, it's created on the fly. No-op
-- when the plan is already listed. Reads/writes the buffer in-place when one
-- is loaded.
local function append_to_next_plans(git_root, plan_name)
  local path = M.get_path(git_root)
  local bufnr = find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    lines = vim.split(read_file(path) or '', '\n', { plain = true })
  end

  -- Already present? Bail.
  local in_section = false
  for _, line in ipairs(lines) do
    local h2 = line:match('^##%s+(.-)%s*$')
    if h2 then in_section = (h2:lower() == 'next plans') end
    if in_section and line:match('^%-%s+' .. vim.pesc(plan_name) .. '%s*$') then
      return
    end
  end

  -- Locate `## next plans` and the start of the next section.
  local np_start, np_end
  for i, line in ipairs(lines) do
    if line:match('^##%s+next plans%s*$') then np_start = i
    elseif np_start and not np_end and line:match('^##%s') then np_end = i - 1 end
  end

  if not np_start then
    -- No masterplan structure yet — let fix() build the skeleton first.
    M.fix(git_root)
    return append_to_next_plans(git_root, plan_name)
  end
  if not np_end then np_end = #lines end
  -- Trim trailing blank lines inside the section.
  local insert_at = np_end + 1
  while insert_at > np_start + 1 and (lines[insert_at - 1] == nil or lines[insert_at - 1] == '') do
    insert_at = insert_at - 1
  end
  table.insert(lines, insert_at, '- ' .. plan_name)

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    write_file(path, table.concat(lines, '\n'))
  end
end

-- Create a new docs/plans/<NNNN-slug>/plan.md, add the plan to the masterplan
-- under `## next plans`, and run fix() to reconcile everything (canonical
-- sections, renumbering, plan-shotfile sync). Number is the next free one
-- across docs/plans folders and all masterplan sections.
-- Returns ok_bool, path_or_error.
function M.new_plan(git_root, title)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not title or title:match('^%s*$') then return false, 'empty title' end
  local slug = M.slugify(title)
  if slug == '' then return false, 'invalid title' end

  local parsed = M.parse(read_file(M.get_path(git_root)) or '')
  local plan_name = string.format('%04d-%s',
    M.next_free_plan_number(git_root, parsed.sections), slug)

  local plan_dir = git_root .. '/docs/plans/' .. plan_name
  vim.fn.mkdir(plan_dir, 'p')
  local path = plan_dir .. '/plan.md'
  if not write_file(path, '# ' .. plan_name .. '\n\n') then
    return false, 'cannot write ' .. path
  end

  append_to_next_plans(git_root, plan_name)
  M.fix(git_root)
  return true, path
end

-- Fix masterplan.md: rewrites via parse/render and syncs each plan's shotfile.
-- Start number for `## next plans` is max(existing plan numbers) + 1 so it
-- never collides with plans already started. After renumbering, every plan in
-- every section gets its shotfile reconciled.
function M.fix(git_root)
  if not git_root or git_root == '' then return false, 'no git root' end
  local path = M.get_path(git_root)
  vim.fn.mkdir(git_root .. '/docs/plans', 'p')

  local bufnr = find_loaded_buf(path)
  local content
  if bufnr then
    content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  else
    content = read_file(path) or ''
  end

  local parsed = M.parse(content)
  local start = M.max_plan_number(git_root, parsed.sections) + 1
  local new = M.render(parsed, M.get_title(git_root), { start_number = start })

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false,
      vim.split(new:gsub('\n$', ''), '\n', { plain = true }))
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    if not write_file(path, new) then return false, 'cannot write ' .. path end
  end

  -- Sync plan shotfiles with the post-render (renumbered) plan names.
  for _, section_name in ipairs(SECTIONS) do
    for _, entry in ipairs(parsed.sections[section_name] or {}) do
      local plan_name = M.extract_plan_name(entry.text)
      if plan_name then
        M.ensure_plan_shotfile(git_root, plan_name)
      end
    end
  end

  return true
end

-- Move the plan on the given 1-based line (and its indented children) to the
-- top of `## done` with a trailing timestamp.
function M.mark_done(git_root, lnum)
  if not git_root or git_root == '' then return false, 'no git root' end
  local path = M.get_path(git_root)
  local bufnr = find_loaded_buf(path)

  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local content = read_file(path)
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

  -- Collect [lnum .. end_at] = entry line + its child lines.
  local end_at = lnum
  for j = lnum + 1, #lines do
    local nxt = lines[j]
    if is_header(nxt) or is_top_entry(nxt) or not is_child_line(nxt) then break end
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

  -- Only strip a pre-existing `(YYYY-MM-DD HH:MM:SS)` tail — leave `(description)` alone.
  local body = entry:gsub(TIMESTAMP_TAIL, '')
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
    if not write_file(path, table.concat(lines, '\n')) then
      return false, 'cannot write'
    end
  end
  return true
end

-- Extract the first plan reference (NNNN-slug) from a line. Returns the
-- matched "NNNN-<slug>" string or nil.
function M.extract_plan_name(line)
  if type(line) ~= 'string' then return nil end
  return line:match('(%d%d%d%d%-[%l%d][%w%-]*)')
end

-- Resolve where a plan's shotfile lives under .hal/util/shooter/shotfiles/docs/plans.
-- Returns (action, target_path, old_path):
--   action = 'exists' → target_path already exists
--   action = 'rename' → an NNNN-<slug>.md with a different number exists;
--                       it lives at old_path and should be renamed to target_path
--   action = 'new'    → no existing file; target_path should be created
function M.resolve_plan_file(git_root, plan_name)
  if not git_root or git_root == '' then return nil, 'no git root' end
  if not plan_name or plan_name == '' then return nil, 'no plan name' end

  local plans_dir = git_root .. '/.hal/util/shooter/shotfiles/docs/plans'
  local target = plans_dir .. '/' .. plan_name .. '.md'

  if vim.fn.filereadable(target) == 1 then
    return 'exists', target
  end

  local slug = plan_name:match('^%d%d%d%d%-(.+)$')
  if slug and vim.fn.isdirectory(plans_dir) == 1 then
    local pattern = plans_dir .. '/[0-9][0-9][0-9][0-9]-' .. slug .. '.md'
    local matches = vim.fn.glob(pattern, false, true)
    if matches and #matches > 0 then
      return 'rename', target, matches[1]
    end
  end

  return 'new', target
end

-- Open/rename/create the shotfile corresponding to the plan referenced on the
-- given line. Returns ok_bool, action_string (or error string when ok=false).
function M.edit_plan_at_line(git_root, line)
  if not git_root or git_root == '' then return false, 'no git root' end
  local plan_name = M.extract_plan_name(line)
  if not plan_name then return false, 'no plan on current line' end

  local ok, msg = M.ensure_plan_shotfile(git_root, plan_name)
  if not ok then return false, msg end

  local target = git_root .. '/.hal/util/shooter/shotfiles/docs/plans/'
    .. plan_name .. '.md'
  vim.cmd('edit ' .. vim.fn.fnameescape(target))
  return true, msg == 'exists' and 'opened' or msg
end

-- Open docs/plans/<NNNN-slug>/<kind>.md for the plan referenced on the given
-- line. `kind` must be 'plan' | 'context' | 'spec'. Returns ok_bool, msg.
function M.open_plan_file(git_root, line, kind)
  if not git_root or git_root == '' then return false, 'no git root' end
  if kind ~= 'plan' and kind ~= 'context' and kind ~= 'spec' then
    return false, 'invalid kind: ' .. tostring(kind)
  end
  local plan_name = M.extract_plan_name(line)
  if not plan_name then return false, 'no plan on current line' end
  local path = git_root .. '/docs/plans/' .. plan_name .. '/' .. kind .. '.md'
  if vim.fn.filereadable(path) ~= 1 then
    return false, 'no ' .. kind .. '.md for ' .. plan_name
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  return true, 'opened'
end

return M

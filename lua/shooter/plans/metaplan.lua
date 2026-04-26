-- Metaplan file helpers: parse / fix / mark_done for docs/plans/metaplan.md.
-- The fix pass normalizes title, canonical section order, gap-fills the
-- numbering in `## next plans`, renames any drifted plan FOLDER on disk
-- (skipping plans whose folder already contains spec.md — those are locked),
-- and moves description-paren + indented child notes from each entry into
-- the matching plan's idea.md under `## shot N`.

local M = {}

-- Section order is also the precedence order used by classify_plan. Done is
-- sticky (the user marks plans done via <space>pd; fix() never auto-moves
-- plans into or out of done). Every other section is auto-managed: fix()
-- re-classifies every plan on every run based on the files inside its
-- docs/plans/<NNNN-slug>/ folder.
local SECTIONS = { 'in progress', 'planned', 'specified', 'next plans', 'done' }
local AUTO_SECTIONS = { 'in progress', 'planned', 'specified', 'next plans' }
local TIMESTAMP_TAIL = '%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)$'
local COMMIT_PATHS = {
  'docs/plans',
}
local COMMIT_MSG = 'chore(plans): sync metaplan + plan ideas'

function M.get_path(git_root)
  return git_root .. '/docs/plans/metaplan.md'
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
    return string.format('# metaplan %s (%s)', repo, alias)
  end
  return string.format('# metaplan %s', repo)
end

-- Classify a plan into one of the auto-managed sections based on the
-- files inside docs/plans/<plan_name>/ in ANY worktree. A plan started
-- in a sibling worktree (e.g. someone added spec.md there) must register
-- as `specified` even if main hasn't seen the file yet — otherwise pf
-- would renumber a plan that's actively being worked on. Order of
-- checks (most-committed first):
--   * hal.yml has `started_at:` with a non-empty value → 'in progress'
--   * masterplan.md present → 'planned'
--   * spec.md present → 'specified'
--   * else → 'next plans'
-- `## done` is sticky — only mark_done puts a plan there, fix never
-- auto-moves plans into or out of done.
-- Pass `worktree_roots` to skip the redundant `git worktree list` subprocess
-- when calling in a tight loop (fix() does this — single git call per pf).
function M.classify_plan(git_root, plan_name, worktree_roots)
  if not git_root or not plan_name or plan_name == '' then
    return 'next plans'
  end
  worktree_roots = worktree_roots or M.list_worktree_roots(git_root)
  local has_started, has_masterplan, has_spec = false, false, false
  for _, root in ipairs(worktree_roots) do
    local folder = root .. '/docs/plans/' .. plan_name
    if vim.fn.isdirectory(folder) == 1 then
      if not has_started
          and vim.fn.filereadable(folder .. '/hal.yml') == 1 then
        local f = io.open(folder .. '/hal.yml', 'r')
        if f then
          local content = f:read('*a') or ''
          f:close()
          if content:match('[\n^]%s*started_at:%s*[%w%d]')
              or content:match('^started_at:%s*[%w%d]') then
            has_started = true
          end
        end
      end
      if not has_masterplan
          and vim.fn.filereadable(folder .. '/masterplan.md') == 1 then
        has_masterplan = true
      end
      if not has_spec
          and vim.fn.filereadable(folder .. '/spec.md') == 1 then
        has_spec = true
      end
    end
    if has_started then break end  -- short-circuit
  end
  if has_started then return 'in progress' end
  if has_masterplan then return 'planned' end
  if has_spec then return 'specified' end
  return 'next plans'
end

-- List the basenames of files inside <wt_root>/docs/plans/<plan_name>/.
-- Returns {} if the folder is missing or empty. Sub-directories are
-- collapsed to their basename (so a stray subfolder counts as "extra
-- content" beyond idea.md, blocking pD's content rule).
function M.plan_files_in_worktree(wt_root, plan_name)
  local out = {}
  if not wt_root or not plan_name then return out end
  local folder = wt_root .. '/docs/plans/' .. plan_name
  if vim.fn.isdirectory(folder) ~= 1 then return out end
  for _, name in ipairs(vim.fn.readdir(folder)) do
    table.insert(out, name)
  end
  return out
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

-- True iff `s` is a `(YYYY-MM-DD HH:MM:SS)` timestamp paren — used to skip
-- the metadata timestamp on `## done` entries when extracting the user's
-- description-paren content for plan-shotfile injection.
local function is_timestamp_paren(s)
  return type(s) == 'string'
    and s:match('^%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)$') ~= nil
end

-- Extract the FIRST description-paren `(...)` group from `text`, ignoring any
-- terminal `(YYYY-MM-DD HH:MM:SS)` timestamp. Returns the inner text (no
-- surrounding parens) or nil. The remainder of the entry (with the matched
-- paren removed, but the timestamp tail preserved) is returned alongside.
local function extract_description_paren(text)
  if type(text) ~= 'string' or text == '' then return nil, text end
  -- Walk paren groups left-to-right, picking the first non-timestamp.
  local cursor, before = 1, ''
  while cursor <= #text do
    local s, e = text:find('%b()', cursor)
    if not s then break end
    local paren = text:sub(s, e)
    if is_timestamp_paren(paren) then
      cursor = e + 1
    else
      local inner = paren:sub(2, -2):match('^%s*(.-)%s*$')
      if not inner or inner == '' then return nil, text end
      before = text:sub(1, s - 1):match('^(.-)%s*$') or ''
      local after = text:sub(e + 1):match('^%s*(.*)$') or ''
      local cleaned = before
      if after ~= '' then
        cleaned = cleaned == '' and after or (cleaned .. ' ' .. after)
      end
      return inner, cleaned
    end
  end
  return nil, text
end

-- Convert child-note lines from a parsed metaplan entry into bullet lines
-- suitable for inclusion under a `## shot N` heading. Drops blank lines and
-- de-indents one level (2 spaces) so the top-level notes become top-level
-- bullets while sub-notes stay nested. Returns a list of strings.
local function dedent_child_notes(children)
  local out = {}
  for _, line in ipairs(children or {}) do
    if line:match('%S') then
      local stripped = line:gsub('^  ', '', 1)
      table.insert(out, stripped)
    end
  end
  return out
end

-- Extract description-paren content + child notes from a parsed entry. Returns
-- (paren_inner, note_lines, cleaned_text, had_extras_bool). When `had_extras`
-- is false the entry has nothing to move into a plan shotfile.
function M.extract_extras(entry)
  if type(entry) ~= 'table' then return nil, {}, '', false end
  local paren, cleaned = extract_description_paren(entry.text or '')
  local notes = dedent_child_notes(entry.children)
  local had = (paren ~= nil) or (#notes > 0)
  return paren, notes, cleaned or entry.text, had
end

-- Enumerate every worktree of the repo at git_root. Returns a deduped array
-- of absolute paths (resolved via fs_realpath). Falls back to {git_root} when
-- git is unavailable or no worktrees are reported.
function M.list_worktree_roots(git_root)
  if not git_root or git_root == '' then return {} end
  local out = vim.fn.system({ 'git', '-C', git_root, 'worktree', 'list',
    '--porcelain' })
  if vim.v.shell_error ~= 0 then return { git_root } end
  local seen, roots = {}, {}
  for line in out:gmatch('[^\n]+') do
    local path = line:match('^worktree%s+(.+)$')
    if path then
      local resolved = vim.uv.fs_realpath(path) or path
      if not seen[resolved] and vim.fn.isdirectory(resolved) == 1 then
        seen[resolved] = true
        table.insert(roots, resolved)
      end
    end
  end
  if #roots == 0 then return { git_root } end
  return roots
end

-- Build the set `{ [N] = true }` of plan numbers that are "already committed"
-- and therefore must NOT be reassigned by `## next plans` gap-fill. The set is
-- the union of:
--   * NNNN-* folder names under docs/plans/ across every worktree of the repo
--     (so a plan started in another worktree still reserves its number), with
--     folders matching MAIN's TENTATIVE `## next plans` entries excluded
--     (those are placeholders created by new_plan and renamed by fix)
--   * NNNN entries in MAIN metaplan's in progress / planned / backlog / done
--     sections
--   * NNNN entries from `## next plans` whose folder contains spec.md
--     (locked — agents have started; do not renumber)
-- Pass `worktree_roots` to avoid the redundant `git worktree list` subprocess
-- when calling in a tight loop (fix() does this — single git call per pf).
function M.collect_used_numbers(git_root, sections, worktree_roots)
  local used = {}
  local function add(n) if n and n > 0 then used[n] = true end end

  worktree_roots = worktree_roots or M.list_worktree_roots(git_root)

  -- `## next plans` entries are tentative — their numbers can be reassigned
  -- by gap-fill, so they don't count as "used". Plans elsewhere (in
  -- progress / planned / specified / done) DO count. Plus every NNNN-* folder
  -- in any worktree that doesn't match a tentative entry.
  local tentative_set = {}
  for _, entry in ipairs((sections or {})['next plans'] or {}) do
    local pn = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
    if pn then tentative_set[pn] = true end
  end

  for _, root in ipairs(worktree_roots) do
    local plans_dir = root .. '/docs/plans'
    if vim.fn.isdirectory(plans_dir) == 1 then
      for _, name in ipairs(vim.fn.readdir(plans_dir)) do
        local pname = name:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
        if pname and not tentative_set[pname] then
          add(tonumber(pname:match('^(%d%d%d%d)%-')))
        end
      end
    end
  end

  sections = sections or {}
  for _, sect in ipairs({ 'in progress', 'planned', 'specified', 'done' }) do
    for _, entry in ipairs(sections[sect] or {}) do
      add(tonumber(entry.text:match('^(%d%d%d%d)%-')))
    end
  end
  return used
end

-- Smallest N >= 1 where exactly k-1 smaller numbers are also free in `used`.
-- I.e. the number that gap-fill would assign to the k-th `## next plans`
-- entry, given a committed used set. Used by `next_free_plan_number` so
-- `new_plan` picks the same number `fix` would assign to a newly appended
-- entry (preventing folder/metaplan divergence).
function M.next_plans_number_at(used, k)
  used = used or {}
  if not k or k < 1 then k = 1 end
  local n, count = 0, 0
  while count < k do
    n = n + 1
    if not used[n] then count = count + 1 end
  end
  return n
end

-- Next free plan number for `new_plan`. Aligned with fix's gap-fill: returns
-- the number a freshly-appended `## next plans` entry would be assigned by
-- render() after fix runs.
function M.next_free_plan_number(git_root, sections)
  local used = M.collect_used_numbers(git_root, sections)
  local current = (sections or {})['next plans'] or {}
  return M.next_plans_number_at(used, #current + 1)
end

-- Render parsed + title back to canonical metaplan content.
-- `## next plans` entries are renumbered using gap-fill: each entry gets the
-- smallest N >= 1 not in `opts.used_numbers` and not yet assigned in this
-- pass. When `used_numbers` is omitted, falls back to sequential renumbering
-- from the first entry's NNNN- prefix (or 1) so the function stays usable in
-- isolation. The pre-paren portion is slugified; anything from the first `(`
-- onwards plus child notes is preserved verbatim.
function M.render(parsed, title, opts)
  opts = opts or {}
  local sections = parsed.sections

  local next_plans = sections['next plans'] or {}
  if #next_plans > 0 then
    local function rewrite(entry, n)
      local stripped = strip_prefix(entry.text)
      local name, rest = split_at_parens(stripped)
      local slug = M.slugify(name)
      if slug == '' then slug = 'plan' end
      if rest ~= '' then
        entry.text = string.format('%04d-%s %s', n, slug, rest)
      else
        entry.text = string.format('%04d-%s', n, slug)
      end
    end

    if opts.used_numbers then
      local used = {}
      for k, v in pairs(opts.used_numbers) do used[k] = v end
      local cursor = 0
      for _, entry in ipairs(next_plans) do
        if opts.is_locked and opts.is_locked(entry) then
          -- Locked entry: keep its committed NNNN, only re-slugify.
          local n = tonumber(entry.text:match('^(%d%d%d%d)%-'))
          if n then rewrite(entry, n) end
        else
          repeat cursor = cursor + 1 until not used[cursor]
          used[cursor] = true
          rewrite(entry, cursor)
        end
      end
    else
      local start = tonumber(next_plans[1].text:match('^(%d%d%d%d)%-')) or 1
      for i, entry in ipairs(next_plans) do
        rewrite(entry, start + i - 1)
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

-- Path to the idea.md for a plan: docs/plans/<plan_name>/idea.md.
function M.idea_path(git_root, plan_name)
  return git_root .. '/docs/plans/' .. plan_name .. '/idea.md'
end

-- Make sure docs/plans/<plan_name>/idea.md exists, creating the plan folder
-- and a title-only stub file when missing. Keeps the `# <path>` title in
-- sync with the canonical idea.md path. Idempotent. Returns ok_bool, action
-- where action is one of 'exists' | 'created' (no rename action — folder
-- renames are handled by fix() and rename_plan, not by this helper).
function M.ensure_plan_idea(git_root, plan_name)
  if not git_root or not plan_name or plan_name == '' then
    return false, 'no git_root/plan_name'
  end
  local files = require('shooter.core.files')
  local target = M.idea_path(git_root, plan_name)

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

local SHOT_HEADER = '^##%s+x?%s*shot%s+(%d+)'
local OPEN_SHOT_HEADER = '^##%s+shot%s+(%d+)'

-- Inject the user's description-paren + child notes for `plan_name` into its
-- idea.md (docs/plans/<plan_name>/idea.md). If the topmost shot in the file
-- is open (`## shot N` without `x`/timestamp), append the bullet lines at
-- the end of that shot's body. Otherwise insert a new `## shot K` section
-- (K = max existing shot # + 1, or 1) above the topmost existing shot — or
-- at the top of the body when the file has no shots yet. No-op when both
-- `paren_text` is nil/empty and `note_lines` is empty. Returns ok_bool.
function M.apply_extras_to_idea(git_root, plan_name, paren_text, note_lines)
  if not git_root or git_root == '' then return false end
  if not plan_name or plan_name == '' then return false end
  note_lines = note_lines or {}
  local has_paren = paren_text and paren_text ~= ''
  if not has_paren and #note_lines == 0 then return true end

  -- Make sure the idea.md exists (creates plan folder + stub if missing).
  local ok = M.ensure_plan_idea(git_root, plan_name)
  if not ok then return false end

  local path = M.idea_path(git_root, plan_name)
  local bufnr = find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    lines = vim.split(read_file(path) or '', '\n', { plain = true })
  end

  -- Locate the topmost shot header and decide append-vs-insert.
  local first_shot_line, first_shot_open
  local max_n = 0
  for i, line in ipairs(lines) do
    local n = line:match(SHOT_HEADER)
    if n then
      n = tonumber(n)
      if n and n > max_n then max_n = n end
      if not first_shot_line then
        first_shot_line = i
        first_shot_open = line:match(OPEN_SHOT_HEADER) ~= nil
      end
    end
  end

  local bullets = {}
  if has_paren then table.insert(bullets, '- ' .. paren_text) end
  for _, n in ipairs(note_lines) do
    -- note already starts with `- ` (top-level bullet) since dedent_child_notes
    -- stripped only one level; otherwise prefix with bullet for safety.
    if n:match('^%-%s+') or n:match('^%s+%-%s+') then
      table.insert(bullets, n)
    else
      table.insert(bullets, '- ' .. n)
    end
  end

  if first_shot_line and first_shot_open then
    -- Append at end of the open shot's body.
    local shot_end = #lines
    for j = first_shot_line + 1, #lines do
      if lines[j]:match(SHOT_HEADER) then shot_end = j - 1; break end
    end
    while shot_end > first_shot_line and lines[shot_end] == '' do
      shot_end = shot_end - 1
    end
    for k = #bullets, 1, -1 do
      table.insert(lines, shot_end + 1, bullets[k])
    end
  else
    -- Insert a new shot section.
    local new_n = max_n + 1
    local block = { '## shot ' .. new_n }
    for _, b in ipairs(bullets) do table.insert(block, b) end
    table.insert(block, '')

    if first_shot_line then
      -- Insert above the topmost (shooted) shot, with a blank separator.
      local insert_at = first_shot_line
      while insert_at > 1 and lines[insert_at - 1] == '' do
        insert_at = insert_at - 1
      end
      for k = #block, 1, -1 do
        table.insert(lines, insert_at, block[k])
      end
      -- Ensure exactly one blank line between the new block and the next shot.
      if lines[insert_at + #block] ~= '' then
        table.insert(lines, insert_at + #block, '')
      end
    else
      -- No shots yet: append after the title (and any leading blanks).
      local insert_at = 1
      if lines[1] and lines[1]:match('^#%s') then
        insert_at = 2
        while lines[insert_at] == '' do insert_at = insert_at + 1 end
      end
      -- Make sure there's a blank line separating title from the new shot.
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
    write_file(path, table.concat(lines, '\n'))
  end
  return true
end

-- Append `- <plan_name>` under `## next plans` in metaplan.md. If the
-- metaplan file or the section is missing, it's created on the fly. No-op
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
    -- Metaplan is missing `## next plans` — append the section inline.
    -- (Using M.fix here would re-enter the adopt-orphan step, which would
    -- claim the new plan's folder for `## in progress` before we get a
    -- chance to register it in `## next plans`.)
    if #lines > 0 and lines[#lines] ~= '' then table.insert(lines, '') end
    table.insert(lines, '## next plans')
    np_start = #lines
    np_end = #lines
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

-- Create a new docs/plans/<NNNN-slug>/plan.md, add the plan to the metaplan
-- under `## next plans`, and run fix() to reconcile everything (canonical
-- sections, renumbering, plan-shotfile sync). Number is the next free one
-- across docs/plans folders and all metaplan sections.
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

-- Rename a plan's folder docs/plans/<old>/ → docs/plans/<new>/ in MAIN.
-- Worktrees are NOT touched — main is canonical for plan management;
-- worktrees pick up the rename when the user merges main into them via
-- /mfm. Updates the title in plan.md / context.md / spec.md / idea.md /
-- masterplan.md to match. No-op when the old folder doesn't exist;
-- refuses when the new folder already exists. Returns ok_bool, msg.
local function rename_plan_folder(git_root, old_name, new_name)
  if old_name == new_name then return true, 'unchanged' end
  local plans_rel = 'docs/plans'
  local old_folder = git_root .. '/' .. plans_rel .. '/' .. old_name
  local new_folder = git_root .. '/' .. plans_rel .. '/' .. new_name
  if vim.fn.isdirectory(old_folder) ~= 1 then return true, 'no folder' end
  if vim.fn.isdirectory(new_folder) == 1 then
    return false, new_folder .. ' already exists'
  end

  local files = require('shooter.core.files')

  -- Save+close any loaded buffers under the old folder so the rename
  -- doesn't collide with stale buffer state.
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

  -- Update the canonical title in each known plan-folder file.
  for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
    local p = new_folder .. '/' .. kind .. '.md'
    if vim.fn.filereadable(p) == 1 then
      files.update_file_title(p, files.title_from_path(p))
    end
  end

  return true
end

-- Fix metaplan.md: rewrites via parse/render, gap-fills `## next plans` (each
-- entry gets the smallest unused NNNN; locked entries — those whose plan
-- folder already has spec.md — keep their number), renames any drifted plan
-- FOLDER on disk to match its post-render name, and creates a stub idea.md
-- in any plan folder that doesn't have one yet.
function M.fix(git_root)
  if not git_root or git_root == '' then return false, 'no git root' end
  local path = M.get_path(git_root)
  vim.fn.mkdir(git_root .. '/docs/plans', 'p')

  -- worktree_roots is used ONLY to seed the "used numbers" set so
  -- gap-fill avoids collisions with plans started in other worktrees.
  -- pf never edits worktrees — main is canonical for plan management.
  local worktree_roots = M.list_worktree_roots(git_root)

  local bufnr = find_loaded_buf(path)
  local content
  if bufnr then
    content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  else
    content = read_file(path) or ''
  end

  local parsed = M.parse(content)

  -- 1. `## done` is sticky. Capture it first so reclassification doesn't
  --    touch it.
  local done_entries = parsed.sections['done'] or {}
  local in_done = {}
  for _, e in ipairs(done_entries) do
    local pn = M.extract_plan_name(e.text)
    if pn then in_done[pn] = true end
  end

  -- 2. Collect every plan we want to reclassify: every metaplan entry NOT
  --    in done, plus every NNNN-<slug>/ folder in MAIN that isn't already
  --    in the metaplan. Preserve next-plans insertion order so gap-fill is
  --    stable across runs. Track each plan's current section so we can
  --    keep no-folder plans where the user placed them.
  local plan_entries = {}      -- ordered list of entry tables
  local plan_index = {}        -- plan_name → index in plan_entries
  local next_plans_order = {}  -- key (plan_name or text) → original index
  local function add_plan_entry(entry)
    local pn = M.extract_plan_name(entry.text)
    if pn then
      if in_done[pn] or plan_index[pn] then return end
      plan_index[pn] = #plan_entries + 1
    end
    table.insert(plan_entries, entry)
  end
  for i, entry in ipairs(parsed.sections['next plans'] or {}) do
    local key = M.extract_plan_name(entry.text) or entry.text
    next_plans_order[key] = i
  end
  for _, section_name in ipairs(AUTO_SECTIONS) do
    for _, entry in ipairs(parsed.sections[section_name] or {}) do
      add_plan_entry(entry)
    end
  end
  -- Also pick up entries from a deprecated `## backlog` section so user
  -- data is preserved (will be auto-classified into the new sections).
  for _, entry in ipairs(parsed.sections['backlog'] or {}) do
    add_plan_entry(entry)
  end
  -- Adopt orphan folders in MAIN (folders whose plan isn't already in the
  -- metaplan, and isn't in done). With auto-classification they'll land
  -- in the right section by file presence — not blindly in `## in progress`.
  local docs_plans = git_root .. '/docs/plans'
  if vim.fn.isdirectory(docs_plans) == 1 then
    for _, name in ipairs(vim.fn.readdir(docs_plans)) do
      local pn = name:match('^(%d%d%d%d%-[%l%d][%w%-]*)$')
      if pn and not in_done[pn] and not plan_index[pn]
          and vim.fn.isdirectory(docs_plans .. '/' .. name) == 1 then
        add_plan_entry({ text = pn, children = {} })
      end
    end
  end

  -- 3. Move description-paren + child notes into each plan's idea.md and
  --    strip them from the metaplan entry.
  for _, entry in ipairs(plan_entries) do
    local plan_name = M.extract_plan_name(entry.text)
    if plan_name then
      local paren, notes, cleaned, had = M.extract_extras(entry)
      if had then
        M.apply_extras_to_idea(git_root, plan_name, paren, notes)
        entry.text = cleaned
        entry.children = {}
      end
    end
  end

  -- 4. Auto-classify each plan into a section by file presence.
  local classified = {
    ['in progress'] = {},
    ['planned'] = {},
    ['specified'] = {},
    ['next plans'] = {},
  }
  for _, entry in ipairs(plan_entries) do
    local plan_name = M.extract_plan_name(entry.text)
    -- classify_plan scans ALL worktrees, so a plan with spec.md in a
    -- sibling worktree (work-in-progress there) lands in `## specified`
    -- and is preserved from gap-fill renumbering. No folder anywhere
    -- means classify_plan returns `next plans` (the default).
    local section = (plan_name
        and M.classify_plan(git_root, plan_name, worktree_roots))
      or 'next plans'
    table.insert(classified[section], entry)
  end

  -- 5. Sort each auto-classified section. in progress / planned / specified
  --    sort alphabetically by NNNN-slug. `## next plans` preserves the
  --    user's original order; new plans (no original index) come last in
  --    alphabetical order so gap-fill is deterministic.
  for _, sec in ipairs({ 'in progress', 'planned', 'specified' }) do
    table.sort(classified[sec], function(a, b) return a.text < b.text end)
  end
  table.sort(classified['next plans'], function(a, b)
    local ka = M.extract_plan_name(a.text) or a.text
    local kb = M.extract_plan_name(b.text) or b.text
    local oa = next_plans_order[ka]
    local ob = next_plans_order[kb]
    if oa and ob then return oa < ob end
    if oa then return true end
    if ob then return false end
    return a.text < b.text
  end)

  -- Replace parsed.sections with the classified result + sticky done.
  parsed.sections = classified
  parsed.sections['done'] = done_entries
  parsed.order = SECTIONS

  -- 6. Snapshot `## next plans` pre-render so we can rename folders after
  --    the gap-fill renumbers entries.
  local next_pre = {}
  for i, entry in ipairs(parsed.sections['next plans'] or {}) do
    next_pre[i] = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
  end

  local used = M.collect_used_numbers(git_root, parsed.sections, worktree_roots)

  local new = M.render(parsed, M.get_title(git_root), { used_numbers = used })

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false,
      vim.split(new:gsub('\n$', ''), '\n', { plain = true }))
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    if not write_file(path, new) then return false, 'cannot write ' .. path end
  end

  -- 7. Rename plan folders in MAIN for renumbered `## next plans` entries.
  --    Worktrees are NEVER touched — main is canonical; worktrees pull via
  --    /mfm when they want to sync. (`merge=ours` for metaplan.md in
  --    .gitattributes prevents WT→main merge from clobbering this.)
  local renames = {}
  for i, entry in ipairs(parsed.sections['next plans'] or {}) do
    local pre = next_pre[i]
    local post = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
    if pre and post and pre ~= post then
      table.insert(renames, { pre = pre, post = post })
    end
  end
  for _, r in ipairs(renames) do
    rename_plan_folder(git_root, r.pre, r.post)
  end

  -- fix() emits no cmdline output of its own — the caller controls all
  -- user-visible messaging so vim's hit-enter prompt isn't triggered by
  -- a long sequence of progress messages.
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

-- Open/create the idea.md corresponding to the plan referenced on the given
-- line. Returns ok_bool, action_string (or error string when ok=false).
-- action_string is 'opened' when the file already existed, otherwise
-- 'created' (created the plan folder and a title-only stub).
function M.edit_plan_at_line(git_root, line)
  if not git_root or git_root == '' then return false, 'no git root' end
  local plan_name = M.extract_plan_name(line)
  if not plan_name then return false, 'no plan on current line' end

  local ok, msg = M.ensure_plan_idea(git_root, plan_name)
  if not ok then return false, msg end

  vim.cmd('edit ' .. vim.fn.fnameescape(M.idea_path(git_root, plan_name)))
  return true, msg == 'exists' and 'opened' or msg
end

-- Open docs/plans/<NNNN-slug>/<kind>.md for the plan referenced on the
-- given line. `kind` must be 'plan' | 'context' | 'spec' | 'masterplan'.
-- Returns ok_bool, msg.
function M.open_plan_file(git_root, line, kind)
  if not git_root or git_root == '' then return false, 'no git root' end
  if kind ~= 'plan' and kind ~= 'context' and kind ~= 'spec'
      and kind ~= 'masterplan' then
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

-- Flush any modified buffers whose file lives under docs/plans/, so
-- `git add` sees the latest content the user actually typed.
local function flush_plans_buffers(git_root)
  local resolved_root = vim.uv.fs_realpath(git_root) or git_root
  local prefixes = {}
  for _, rel in ipairs(COMMIT_PATHS) do
    table.insert(prefixes, resolved_root .. '/' .. rel .. '/')
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      local resolved = name ~= '' and (vim.uv.fs_realpath(name) or name) or ''
      if resolved ~= '' then
        for _, prefix in ipairs(prefixes) do
          if resolved:sub(1, #prefix) == prefix then
            vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end)
            break
          end
        end
      end
    end
  end
end

local function git(git_root, args)
  local cmd = { 'git', '-C', git_root }
  for _, a in ipairs(args) do table.insert(cmd, a) end
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

-- git add + commit (no push) the plan folders. Only folders that actually
-- exist are included in the pathspec, so a repo with nothing plan-related
-- yet is a no-op rather than an error.
-- Returns: ok_bool, msg_or_nil, committed_bool
--   ok=true, committed=false → nothing to commit (msg explains)
--   ok=true, committed=true  → committed (msg nil)
--   ok=false                 → failure (msg = error)
function M.commit_plans(git_root, message)
  if not git_root or git_root == '' then return false, 'no git root', false end
  message = message or COMMIT_MSG

  local present = {}
  for _, rel in ipairs(COMMIT_PATHS) do
    if vim.fn.isdirectory(git_root .. '/' .. rel) == 1 then
      table.insert(present, rel)
    end
  end
  if #present == 0 then
    return true, 'plans: no folders to commit', false
  end

  flush_plans_buffers(git_root)

  local add = { 'add', '-A', '--' }
  for _, p in ipairs(present) do table.insert(add, p) end
  local add_out, add_err = git(git_root, add)
  if add_err ~= 0 then
    return false, 'git add failed: ' .. add_out:gsub('\n', ' '), false
  end

  -- Only include pathspecs with actual staged changes in the commit, so
  -- `git commit -- ...` never errors on a pathspec that matches nothing.
  local changed = {}
  for _, p in ipairs(present) do
    local _, err = git(git_root, { 'diff', '--cached', '--quiet', '--', p })
    if err ~= 0 then table.insert(changed, p) end
  end
  if #changed == 0 then
    return true, 'plans: nothing to commit', false
  end

  local commit = { 'commit', '-m', message, '--' }
  for _, p in ipairs(changed) do table.insert(commit, p) end
  local commit_out, commit_err = git(git_root, commit)
  if commit_err ~= 0 then
    return false, 'git commit failed: ' .. commit_out:gsub('\n', ' '), false
  end
  return true, nil, true
end

-- True when `path` is either missing or has at most one non-blank line and
-- that line is a markdown heading. Used by delete_plan to decide whether a
-- deletion is "safe" (stub) or needs user confirmation.
function M.is_stub_file(path)
  if not path or path == '' then return false end
  if vim.fn.filereadable(path) ~= 1 then return false end
  local content = read_file(path) or ''
  local non_blank = {}
  for _, line in ipairs(vim.split(content, '\n', { plain = true })) do
    if line:match('%S') then table.insert(non_blank, line) end
  end
  if #non_blank == 0 then return true end
  if #non_blank == 1 and non_blank[1]:match('^#') then return true end
  return false
end

-- True if `dir` exists AND contains at least one non-stub file or any
-- subdirectory. Used by delete_plan to decide whether to confirm with the user.
function M.folder_has_content(dir)
  if not dir or dir == '' then return false end
  if vim.fn.isdirectory(dir) ~= 1 then return false end
  for _, name in ipairs(vim.fn.readdir(dir)) do
    local p = dir .. '/' .. name
    if vim.fn.isdirectory(p) == 1 then return true end
    if vim.fn.filereadable(p) == 1 and not M.is_stub_file(p) then
      return true
    end
  end
  return false
end

-- Replace the first markdown heading in `path` whose text contains `needle`
-- with the same line, but with `needle` substituted for `replacement`. Only
-- the first heading line is touched. No-op when the file doesn't exist or no
-- heading references `needle`.
local function replace_title_reference(path, needle, replacement)
  if vim.fn.filereadable(path) ~= 1 then return end
  local content = read_file(path)
  if not content then return end
  local lines = vim.split(content, '\n', { plain = true })
  for i, line in ipairs(lines) do
    if line:match('^#[ \t]') then
      if line:find(needle, 1, true) then
        lines[i] = line:gsub(vim.pesc(needle), replacement, 1)
        write_file(path, table.concat(lines, '\n'))
      end
      return
    end
  end
end

-- Locate the metaplan line whose plan reference matches `name` and replace
-- the name with `new_name`. Preserves anything else on the line (parens,
-- trailing text) and leaves indented child notes untouched. Updates a loaded
-- buffer in place when one exists.
function M.rewrite_metaplan_line(git_root, old_name, new_name)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not old_name or old_name == '' then return false, 'no old name' end
  if not new_name or new_name == '' then return false, 'no new name' end
  local path = M.get_path(git_root)
  local bufnr = find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local content = read_file(path)
    if not content then return false, 'metaplan not found' end
    lines = vim.split(content, '\n', { plain = true })
  end

  local found = false
  for i, line in ipairs(lines) do
    if line:match('^%-%s') and M.extract_plan_name(line) == old_name then
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
    if not write_file(path, table.concat(lines, '\n')) then
      return false, 'cannot write ' .. path
    end
  end
  return true
end

-- Remove the first metaplan entry whose plan reference matches `name`,
-- along with its indented child notes (and any trailing blank line in the
-- child block). No-op when no matching entry exists.
function M.remove_metaplan_entry(git_root, name)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not name or name == '' then return false, 'no plan name' end
  local path = M.get_path(git_root)
  local bufnr = find_loaded_buf(path)
  local lines
  if bufnr then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local content = read_file(path)
    if not content then return true end  -- nothing to remove
    lines = vim.split(content, '\n', { plain = true })
  end

  local start_idx
  for i, line in ipairs(lines) do
    if line:match('^%-%s') and M.extract_plan_name(line) == name then
      start_idx = i
      break
    end
  end
  if not start_idx then return true end  -- no-op

  local end_idx = start_idx
  for j = start_idx + 1, #lines do
    local nxt = lines[j]
    if is_header(nxt) or is_top_entry(nxt) or not is_child_line(nxt) then break end
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
    if not write_file(path, table.concat(lines, '\n')) then
      return false, 'cannot write ' .. path
    end
  end
  return true
end

-- Save-and-close any loaded buffer pointing at `path`, so a subsequent
-- rename/delete on disk doesn't collide with stale buffer state.
local function close_buf_for(path)
  local bufnr = find_loaded_buf(path)
  if not bufnr then return end
  if vim.bo[bufnr].modified then
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Rename a plan in MAIN: rename `docs/plans/<old>/` → `docs/plans/<new>/`
-- (carrying plan.md / context.md / spec.md / idea.md / masterplan.md
-- along), update titles, rewrite the metaplan line, commit. Worktrees
-- are NOT touched — main is canonical for plan management; worktrees
-- pick up the rename when the user merges main into them via /mfm.
function M.rename_plan(git_root, old_name, new_name)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not old_name or old_name == '' then return false, 'no old name' end
  if not new_name or new_name == '' then return false, 'no new name' end
  if old_name == new_name then return false, 'name unchanged' end
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
    close_buf_for(old_folder .. '/' .. kind .. '.md')
  end

  if vim.fn.isdirectory(old_folder) == 1 then
    local _, err = git(git_root, { 'mv',
      plans_rel .. '/' .. old_name, plans_rel .. '/' .. new_name })
    if err ~= 0 then
      if not os.rename(old_folder, new_folder) then
        return false, 'failed to rename ' .. old_folder
      end
    end
    -- Update titles: each file's `# docs/plans/<old>/...` heading.
    local files = require('shooter.core.files')
    for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
      local p = new_folder .. '/' .. kind .. '.md'
      if vim.fn.filereadable(p) == 1 then
        replace_title_reference(p, old_name, new_name)
        files.update_file_title(p, files.title_from_path(p))
      end
    end
  end

  local ok, err = M.rewrite_metaplan_line(git_root, old_name, new_name)
  if not ok then return false, err end

  local cok, cmsg, committed = M.commit_plans(git_root,
    'chore(plans): rename ' .. old_name .. ' -> ' .. new_name)
  if not cok then return false, cmsg end
  return true, committed and 'renamed' or 'renamed (nothing to commit)'
end

-- Pre-flight delete check across every worktree. Returns ok_bool,
-- reason_string. Without `force`:
--   * Tier 1: plan_deletable (every WT's folder must be empty or only-idea).
--   * Tier 2: each WT that has the folder must be status-clean inside it.
--   * Tier 3: each WT that has the folder must have no commits on its
--     branch (vs main) touching the folder.
-- Pre-flight delete check for MAIN's copy of the plan folder. Returns
-- ok_bool, reason_string. Without `force`, the folder must contain only
-- idea.md (or be empty / nonexistent) — anything else (plan.md, spec.md,
-- masterplan.md, hal.yml, etc.) means the user has invested work and a
-- normal delete would destroy it. `force=true` bypasses the rule.
-- Worktrees are NOT inspected — main is canonical; worktrees pick up the
-- delete via /mfm later (git's normal handling).
function M.delete_plan_preflight(git_root, name, force)
  if force then return true end
  local files = M.plan_files_in_worktree(git_root, name)
  local extras = {}
  for _, f in ipairs(files) do
    if f ~= 'idea.md' then table.insert(extras, f) end
  end
  if #extras > 0 then
    return false, name .. ' has [' .. table.concat(extras, ', ') .. ']'
  end
  return true
end

-- Delete a plan in MAIN: remove `docs/plans/<name>/` folder + the metaplan
-- entry, run fix(), commit. Worktrees are NOT touched — main is canonical
-- for plan management; worktrees pick up the delete when they /mfm. The
-- `## done` section is sticky, so deleting a done plan also drops it from
-- done (a true erase).
--
-- `opts.folder` (default true) — delete the folder; false to drop only
--   the metaplan entry.
-- `opts.force` (default false) — bypass the content rule (only-idea.md).
function M.delete_plan(git_root, name, opts)
  if not git_root or git_root == '' then return false, 'no git root' end
  if not name or name == '' then return false, 'no plan name' end
  opts = opts or {}
  if opts.folder == nil then opts.folder = true end

  if opts.folder then
    local ok, reason = M.delete_plan_preflight(git_root, name, opts.force)
    if not ok then return false, reason end
  end

  local plans_rel = 'docs/plans'
  local folder = git_root .. '/' .. plans_rel .. '/' .. name
  if opts.folder and vim.fn.isdirectory(folder) == 1 then
    for _, kind in ipairs({ 'plan', 'context', 'spec', 'idea', 'masterplan' }) do
      close_buf_for(folder .. '/' .. kind .. '.md')
    end
    local _, err = git(git_root, { 'rm', '-rf', '--', plans_rel .. '/' .. name })
    if err ~= 0 then vim.fn.delete(folder, 'rf') end
  end

  -- Drop metaplan entry (main only) when the folder is gone, so fix()
  -- doesn't re-adopt a still-present folder.
  if vim.fn.isdirectory(folder) ~= 1 then
    local ok, err = M.remove_metaplan_entry(git_root, name)
    if not ok then return false, err end
  end

  local fok, ferr = M.fix(git_root)
  if not fok then return false, ferr end
  local cok, cmsg, committed = M.commit_plans(git_root,
    'chore(plans): delete ' .. name)
  if not cok then return false, cmsg end
  return true, committed and 'deleted' or 'deleted (nothing to commit)'
end

return M

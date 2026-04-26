-- Markdown → AST: parse metaplan.md content into a structured representation.
-- Also hosts the small text helpers (slugify, strip_prefix, split_at_parens,
-- extract_plan_name, extract_extras, extract_description_paren,
-- dedent_child_notes) used by render and rename seams.

local util = require('shooter.plans.metaplan.util')

local M = {}

-- Slugify: lowercase, collapse non-alphanumeric runs to single '-', trim.
function M.slugify(text)
  local s = (text or ''):lower():gsub('[^a-z0-9]+', '-')
  return (s:gsub('^%-+', ''):gsub('%-+$', ''))
end

-- Strip a leading NNNN- or ????- prefix from the text before slugifying.
function M.strip_prefix(text)
  local rest = text:match('^%d%d%d%d%-(.*)$')
  if rest then return rest end
  rest = text:match('^%?%?%?%?%-(.*)$')
  if rest then return rest end
  return text
end

-- Split an entry text into `name_part` (pre-`(`, for slugifying) and
-- `rest` (from the first `(` to end, kept verbatim). No `(` → rest = "".
function M.split_at_parens(text)
  local name, rest = text:match('^(.-)%s*(%b()%s*.*)$')
  if name and rest and rest ~= '' then
    return name, rest
  end
  local idx = text:find('(', 1, true)
  if idx then
    return text:sub(1, idx - 1):match('^(.-)%s*$'), text:sub(idx)
  end
  return text, ''
end

-- Parse content into { sections = {name → { {text, children}, ... }}, order = {...} }.
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
    elseif current and util.is_top_entry(raw) then
      local text = raw:match('^%-%s+(.-)%s*$')
      local children = {}
      local j = i + 1
      while j <= #lines do
        local nxt = lines[j]
        if util.is_header(nxt) or util.is_top_entry(nxt) then break end
        if not util.is_child_line(nxt) then break end
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

-- Extract the FIRST description-paren `(...)` from `text`, ignoring any
-- terminal `(YYYY-MM-DD HH:MM:SS)` timestamp. Returns (inner, cleaned_text).
function M.extract_description_paren(text)
  if type(text) ~= 'string' or text == '' then return nil, text end
  local cursor, before = 1, ''
  while cursor <= #text do
    local s, e = text:find('%b()', cursor)
    if not s then break end
    local paren = text:sub(s, e)
    if util.is_timestamp_paren(paren) then
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
-- suitable for inclusion under a `## shot N` heading.
function M.dedent_child_notes(children)
  local out = {}
  for _, line in ipairs(children or {}) do
    if line:match('%S') then
      local stripped = line:gsub('^  ', '', 1)
      table.insert(out, stripped)
    end
  end
  return out
end

-- Extract description-paren content + child notes from a parsed entry.
-- Returns (paren_inner, note_lines, cleaned_text, had_extras_bool).
function M.extract_extras(entry)
  if type(entry) ~= 'table' then return nil, {}, '', false end
  local paren, cleaned = M.extract_description_paren(entry.text or '')
  local notes = M.dedent_child_notes(entry.children)
  local had = (paren ~= nil) or (#notes > 0)
  return paren, notes, cleaned or entry.text, had
end

-- Extract the first plan reference (NNNN-slug) from a line.
function M.extract_plan_name(line)
  if type(line) ~= 'string' then return nil end
  return line:match('(%d%d%d%d%-[%l%d][%w%-]*)')
end

return M

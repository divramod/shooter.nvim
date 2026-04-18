-- Find link-like and path-like ranges in a line for syntax highlighting.
-- Pure string logic so it can be unit-tested without a buffer.
local M = {}

-- Patterns ordered by specificity. The first match wins for any given byte;
-- later patterns only fill in gaps.
--
-- Lua patterns are limited (no alternation), so we run each family
-- separately and merge non-overlapping spans.
-- Pattern + optional guard. The guard receives (line, start, end) and
-- returns true to accept the match.
local function preceded_by_word_or_slash(line, s)
  if s <= 1 then return false end
  local prev = line:sub(s - 1, s - 1)
  return prev:match('[%w_/]') ~= nil
end

local PATTERNS = {
  -- Markdown inline link: [text](url) — %b matches balanced brackets/parens.
  { '%b[]%b()' },
  -- Bare URL
  { 'https?://[%w%._~%-/%%?#=&+@!$;:*]+' },
  -- Tilde home path: ~/...
  { '~/[%w%._/%-]*[%w%._%-]' },
  -- Dot-relative: ./foo or ../foo
  { '%.%.?/[%w%._/%-]*[%w%._%-]' },
  -- Slashed path with extension, not starting with / or ~ — tried before
  -- the absolute pattern so "lua/foo/bar.md" wins over "/foo/bar.md".
  -- Guard rejects matches whose first char is preceded by another slash,
  -- so "/tmp/foo.txt" falls through to the absolute pattern.
  { '[%w_][%w%._%-]*/[%w%._/%-]*%.[%w]+',
    function(line, s) return not preceded_by_word_or_slash(line, s) end },
  -- Absolute path with extension (avoid generic "/")
  { '/[%w%._/%-]+%.[%w]+' },
}

-- Collect all spans for a single pattern (optionally filtered by guard).
-- Returns 1-based inclusive { start, end } pairs.
local function collect(line, pat, guard)
  local out = {}
  local i = 1
  while i <= #line do
    local s, e = line:find(pat, i)
    if not s then break end
    if (not guard) or guard(line, s, e) then
      table.insert(out, { s, e })
    end
    i = e + 1
  end
  return out
end

-- True if [s, e] overlaps any range in covered (1-based inclusive).
local function overlaps(covered, s, e)
  for _, r in ipairs(covered) do
    if not (e < r[1] or s > r[2]) then return true end
  end
  return false
end

-- Return an array of { start_col, end_col } using 0-based, end-exclusive
-- coordinates suitable for nvim extmarks. Ranges never overlap.
function M.find_ranges(line)
  if not line or line == '' then return {} end

  local covered = {}
  for _, entry in ipairs(PATTERNS) do
    local pat, guard = entry[1], entry[2]
    for _, span in ipairs(collect(line, pat, guard)) do
      if not overlaps(covered, span[1], span[2]) then
        table.insert(covered, span)
      end
    end
  end

  -- Sort by start column for stable output.
  table.sort(covered, function(a, b) return a[1] < b[1] end)

  local out = {}
  for _, r in ipairs(covered) do
    table.insert(out, { r[1] - 1, r[2] })
  end
  return out
end

return M

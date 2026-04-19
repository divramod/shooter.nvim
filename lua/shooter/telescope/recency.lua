-- Relative time formatting and mtime-based sorting for shotfile entries.
local M = {}

-- Format a duration in seconds as a short relative string (e.g. "5m", "2h 5m",
-- "1d", "3w", "2mo", "1y"). Returns "just now" for < 60s.
function M.format_relative(diff)
  if diff < 0 then diff = 0 end
  if diff < 60 then return string.format('%ds ago', diff) end
  if diff < 3600 then
    return string.format('%dm ago', math.floor(diff / 60))
  end
  if diff < 86400 then
    local h = math.floor(diff / 3600)
    local m = math.floor((diff % 3600) / 60)
    if m > 0 then return string.format('%dh %dm ago', h, m) end
    return string.format('%dh ago', h)
  end
  if diff < 604800 then
    local d = math.floor(diff / 86400)
    local h = math.floor((diff % 86400) / 3600)
    local m = math.floor((diff % 3600) / 60)
    if h > 0 and m > 0 then return string.format('%dd %dh %dm ago', d, h, m) end
    if h > 0 then return string.format('%dd %dh ago', d, h) end
    return string.format('%dd ago', d)
  end
  if diff < 2592000 then
    local w = math.floor(diff / 604800)
    local d = math.floor((diff % 604800) / 86400)
    if d > 0 then return string.format('%dw %dd ago', w, d) end
    return string.format('%dw ago', w)
  end
  if diff < 31536000 then
    return string.format('%dmo ago', math.floor(diff / 2592000))
  end
  return string.format('%dy ago', math.floor(diff / 31536000))
end

-- Return file mtime in seconds since epoch (0 if file is missing).
function M.file_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return (stat and stat.mtime and stat.mtime.sec) or 0
end

-- Sort entries in-place by mtime descending (most recent first). Entries
-- must have a `path` field. Adds `_mtime` to each entry as a side effect.
function M.sort_desc(entries)
  for _, e in ipairs(entries) do
    e._mtime = M.file_mtime(e.path)
  end
  table.sort(entries, function(a, b) return a._mtime > b._mtime end)
  return entries
end

-- Build a display string for an entry that appends "(5m ago)" based on mtime.
function M.append_age(base_display, mtime, now)
  now = now or os.time()
  return string.format('%s (%s)', base_display, M.format_relative(now - mtime))
end

return M

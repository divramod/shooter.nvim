-- Analytics data gathering
local M = {}
local utils = require('shooter.utils')

-- Parse YAML frontmatter from shot file
function M.parse_frontmatter(filepath)
  local file = io.open(filepath, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  local fm, in_fm = {}, false
  for line in content:gmatch('[^\n]+') do
    if line == '---' then if in_fm then break end; in_fm = true
    elseif in_fm then
      local k, v = line:match('^([%w_]+):%s*(.+)$')
      if k and v then fm[k] = v end
    end
  end
  if fm.timestamp then
    local y, m, d, h, min, s = fm.timestamp:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
    if y then fm.time = os.time({ year = y, month = m, day = d, hour = h, min = min, sec = s }) end
  end
  local body = content:match('---\n.-\n---\n(.*)') or ''
  fm.chars, fm.words = #body, select(2, body:gsub('%S+', '')) or 0
  fm.sentences = select(2, body:gsub('[.!?]', '')) or 0
  return fm
end

-- Get all shot files from history directory
function M.get_all_shots(project_filter)
  local history_dir = utils.expand_path('~/.config/shooter.nvim/history')
  local shots = {}
  local handle = io.popen('find "' .. history_dir .. '" -name "shot-*.md" -type f 2>/dev/null')
  if not handle then return shots end
  for filepath in handle:lines() do
    local fm = M.parse_frontmatter(filepath)
    if fm and fm.timestamp and (not project_filter or (fm.repo and fm.repo:find(project_filter, 1, true))) then
      fm.filepath = filepath; table.insert(shots, fm)
    end
  end
  handle:close()
  table.sort(shots, function(a, b) return (a.time or 0) > (b.time or 0) end)
  return shots
end

-- Get time period boundaries
function M.get_time_boundaries()
  local today = os.time({ year = os.date('%Y'), month = os.date('%m'), day = os.date('%d'), hour = 0 })
  return { now = os.time(), today = today, week = today - (tonumber(os.date('%w')) * 86400),
    month = os.time({ year = os.date('%Y'), month = os.date('%m'), day = 1, hour = 0 }),
    year = os.time({ year = os.date('%Y'), month = 1, day = 1, hour = 0 }) }
end

-- Calculate statistics from shots
function M.calculate_stats(shots)
  local bounds = M.get_time_boundaries()
  local stats = { total = #shots, today = 0, this_week = 0, this_month = 0, this_year = 0,
    by_project = {}, total_chars = 0, total_words = 0, total_sentences = 0, time_diffs = {},
    by_file = { today = {}, week = {}, month = {}, year = {}, alltime = {} },
    longest_chars = nil, shortest_chars = nil, longest_words = nil, shortest_words = nil,
    longest_sentences = nil, shortest_sentences = nil }
  local prev_time = nil
  for _, shot in ipairs(shots) do
    local t = shot.time or 0
    if t >= bounds.today then stats.today = stats.today + 1 end
    if t >= bounds.week then stats.this_week = stats.this_week + 1 end
    if t >= bounds.month then stats.this_month = stats.this_month + 1 end
    if t >= bounds.year then stats.this_year = stats.this_year + 1 end
    local repo = shot.repo or 'unknown'
    stats.by_project[repo] = (stats.by_project[repo] or 0) + 1
    stats.total_chars = stats.total_chars + (shot.chars or 0)
    stats.total_words = stats.total_words + (shot.words or 0)
    stats.total_sentences = stats.total_sentences + (shot.sentences or 0)
    -- Track longest/shortest prompts
    local chars, words, sents = shot.chars or 0, shot.words or 0, shot.sentences or 0
    local shot_id = string.format('shot %s', shot.shot or '?')
    local short_src = shot.source and shot.source:match('[^/]+$') or 'unknown'
    if chars > 0 then
      if not stats.longest_chars or chars > stats.longest_chars.value then
        stats.longest_chars = { value = chars, shot = shot_id, source = short_src }
      end
      if not stats.shortest_chars or chars < stats.shortest_chars.value then
        stats.shortest_chars = { value = chars, shot = shot_id, source = short_src }
      end
    end
    if words > 0 then
      if not stats.longest_words or words > stats.longest_words.value then
        stats.longest_words = { value = words, shot = shot_id, source = short_src }
      end
      if not stats.shortest_words or words < stats.shortest_words.value then
        stats.shortest_words = { value = words, shot = shot_id, source = short_src }
      end
    end
    if sents > 0 then
      if not stats.longest_sentences or sents > stats.longest_sentences.value then
        stats.longest_sentences = { value = sents, shot = shot_id, source = short_src }
      end
      if not stats.shortest_sentences or sents < stats.shortest_sentences.value then
        stats.shortest_sentences = { value = sents, shot = shot_id, source = short_src }
      end
    end
    -- Track shots per source file by time period
    local src = shot.source
    if src then
      local short = src:match('[^/]+$') or src
      stats.by_file.alltime[short] = (stats.by_file.alltime[short] or 0) + 1
      if t >= bounds.today then stats.by_file.today[short] = (stats.by_file.today[short] or 0) + 1 end
      if t >= bounds.week then stats.by_file.week[short] = (stats.by_file.week[short] or 0) + 1 end
      if t >= bounds.month then stats.by_file.month[short] = (stats.by_file.month[short] or 0) + 1 end
      if t >= bounds.year then stats.by_file.year[short] = (stats.by_file.year[short] or 0) + 1 end
    end
    if prev_time and t > 0 then table.insert(stats.time_diffs, prev_time - t) end
    prev_time = t
  end
  return stats
end

-- Build mapping of short filenames to full paths from shots
function M.build_path_map(shots)
  local map = {}
  for _, shot in ipairs(shots) do
    if shot.source then
      local short = shot.source:match('[^/]+$') or shot.source
      if not map[short] then map[short] = shot.source end
    end
    if shot.filepath then
      local short = shot.filepath:match('[^/]+$') or shot.filepath
      map[short] = shot.filepath
    end
  end
  return map
end

return M

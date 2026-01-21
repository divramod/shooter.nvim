-- Analytics module for shooter.nvim
local M = {}
local utils = require('shooter.utils')

-- Parse YAML frontmatter from shot file
local function parse_frontmatter(filepath)
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
local function get_all_shots(project_filter)
  local history_dir = utils.expand_path('~/.config/shooter.nvim/history')
  local shots = {}
  local handle = io.popen('find "' .. history_dir .. '" -name "shot-*.md" -type f 2>/dev/null')
  if not handle then return shots end
  for filepath in handle:lines() do
    local fm = parse_frontmatter(filepath)
    if fm and fm.timestamp and (not project_filter or (fm.repo and fm.repo:find(project_filter, 1, true))) then
      fm.filepath = filepath; table.insert(shots, fm)
    end
  end
  handle:close()
  table.sort(shots, function(a, b) return (a.time or 0) > (b.time or 0) end)
  return shots
end

-- Get time period boundaries
local function get_time_boundaries()
  local today = os.time({ year = os.date('%Y'), month = os.date('%m'), day = os.date('%d'), hour = 0 })
  return { now = os.time(), today = today, week = today - (tonumber(os.date('%w')) * 86400),
    month = os.time({ year = os.date('%Y'), month = os.date('%m'), day = 1, hour = 0 }),
    year = os.time({ year = os.date('%Y'), month = 1, day = 1, hour = 0 }) }
end

-- Calculate statistics from shots
local function calculate_stats(shots)
  local bounds = get_time_boundaries()
  local stats = { total = #shots, today = 0, this_week = 0, this_month = 0, this_year = 0,
    by_project = {}, total_chars = 0, total_words = 0, total_sentences = 0, time_diffs = {},
    by_file = { today = {}, week = {}, month = {}, year = {}, alltime = {} },
    -- Track extremes for prompt length
    longest_chars = nil, shortest_chars = nil,
    longest_words = nil, shortest_words = nil,
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

-- Get top N files from a file count table
local function get_top_files(file_counts, n)
  local files = {}
  for name, count in pairs(file_counts) do table.insert(files, { name = name, count = count }) end
  table.sort(files, function(a, b) return a.count > b.count end)
  local result = {}
  for i = 1, math.min(n, #files) do result[i] = files[i] end
  return result
end

-- Format duration in human-readable form
local function format_duration(sec)
  if sec < 60 then return string.format('%ds', sec) end
  if sec < 3600 then return string.format('%dm', math.floor(sec / 60)) end
  if sec < 86400 then return string.format('%.1fh', sec / 3600) end
  return string.format('%.1fd', sec / 86400)
end

-- Generate analytics report
function M.generate_report(project_filter)
  local shots = get_all_shots(project_filter)
  local stats = calculate_stats(shots)
  local lines = {}
  local function add(l) table.insert(lines, l or '') end

  add('# Shooter Analytics' .. (project_filter and (' - ' .. project_filter) or ' (Global)'))
  add(''); add('## Shot Counts'); add('')
  add(string.format('- **Total**: %d shots', stats.total))
  add(string.format('- **Today**: %d', stats.today))
  add(string.format('- **This Week**: %d', stats.this_week))
  add(string.format('- **This Month**: %d', stats.this_month))
  add(string.format('- **This Year**: %d', stats.this_year))
  add('')

  if not project_filter then
    add('## Shots by Project'); add('')
    local projects = {}
    for repo, count in pairs(stats.by_project) do table.insert(projects, { repo = repo, count = count }) end
    table.sort(projects, function(a, b) return a.count > b.count end)
    for _, p in ipairs(projects) do add(string.format('- **%s**: %d shots', p.repo, p.count)) end
    add('')
  end

  add('## Averages'); add('')
  if stats.total > 0 then
    add(string.format('- **Chars/shot**: %.0f', stats.total_chars / stats.total))
    add(string.format('- **Words/shot**: %.0f', stats.total_words / stats.total))
    add(string.format('- **Sentences/shot**: %.1f', stats.total_sentences / stats.total))
  end
  if #stats.time_diffs > 0 then
    local sum = 0; for _, d in ipairs(stats.time_diffs) do sum = sum + d end
    add(string.format('- **Avg time between shots**: %s', format_duration(sum / #stats.time_diffs)))
  end
  add('')

  -- Prompt length extremes section
  add('## Prompt Length Extremes'); add('')
  add('### Longest Prompts')
  if stats.longest_chars then
    add(string.format('- **By Characters**: %d chars (%s in %s)',
      stats.longest_chars.value, stats.longest_chars.shot, stats.longest_chars.source))
  end
  if stats.longest_words then
    add(string.format('- **By Words**: %d words (%s in %s)',
      stats.longest_words.value, stats.longest_words.shot, stats.longest_words.source))
  end
  if stats.longest_sentences then
    add(string.format('- **By Sentences**: %d sentences (%s in %s)',
      stats.longest_sentences.value, stats.longest_sentences.shot, stats.longest_sentences.source))
  end
  add('')
  add('### Shortest Prompts')
  if stats.shortest_chars then
    add(string.format('- **By Characters**: %d chars (%s in %s)',
      stats.shortest_chars.value, stats.shortest_chars.shot, stats.shortest_chars.source))
  end
  if stats.shortest_words then
    add(string.format('- **By Words**: %d words (%s in %s)',
      stats.shortest_words.value, stats.shortest_words.shot, stats.shortest_words.source))
  end
  if stats.shortest_sentences then
    add(string.format('- **By Sentences**: %d sentences (%s in %s)',
      stats.shortest_sentences.value, stats.shortest_sentences.shot, stats.shortest_sentences.source))
  end
  add('')

  -- File rankings section
  add('## File Rankings (Top 5)'); add('')
  local periods = { { key = 'today', label = 'Today' }, { key = 'week', label = 'This Week' },
    { key = 'month', label = 'This Month' }, { key = 'year', label = 'This Year' },
    { key = 'alltime', label = 'All Time' } }
  for _, period in ipairs(periods) do
    local top = get_top_files(stats.by_file[period.key], 5)
    if #top > 0 then
      add('### ' .. period.label)
      for i, f in ipairs(top) do add(string.format('%d. %s (%d)', i, f.name, f.count)) end
      add('')
    end
  end

  add('---'); add(string.format('*Generated: %s*', os.date('%Y-%m-%d %H:%M:%S')))
  return lines
end

-- Show analytics in a new buffer
function M.show(project_filter)
  local lines = M.generate_report(project_filter)
  vim.cmd('enew')
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile, vim.bo.filetype = 'nofile', 'wipe', false, 'markdown'
  local title = project_filter and ('Shooter Analytics - ' .. project_filter) or 'Shooter Analytics (Global)'
  vim.api.nvim_buf_set_name(0, title); vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modifiable = false
end

function M.show_global() M.show(nil) end

function M.show_project()
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  if not git_root then vim.notify('Not in a git repository', vim.log.levels.WARN); return end
  local handle = io.popen('cd "' .. git_root .. '" && git remote get-url origin 2>/dev/null')
  local remote = handle and handle:read('*l') or ''
  if handle then handle:close() end
  M.show(remote:match('github.com[:/]([^/]+/[^/.]+)') or vim.fn.fnamemodify(git_root, ':t'))
end

return M

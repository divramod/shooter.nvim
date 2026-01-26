-- Analytics report generation
local M = {}
local data = require('shooter.analytics.data')
local chart = require('shooter.analytics.chart')

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
function M.generate_report(project_filter, shots)
  shots = shots or data.get_all_shots(project_filter)
  local stats = data.calculate_stats(shots)
  local lines = {}
  local function add(l) table.insert(lines, l or '') end

  add('# Shooter Analytics' .. (project_filter and (' - ' .. project_filter) or ' (Global)'))
  add('')

  -- Daily activity bar chart (at top)
  -- For project analytics: show shotfiles; for global: show repos
  local is_project = project_filter ~= nil
  add('## Daily Activity'); add('```')
  for _, line in ipairs(chart.generate_bar_chart(shots, 30, is_project)) do add(line) end
  add('```'); add('')

  add('## Shot Counts'); add('')
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

return M

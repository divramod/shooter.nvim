-- Analytics module for shooter.nvim
local M = {}
local utils = require('shooter.utils')

-- Parse YAML frontmatter from shot file
local function parse_frontmatter(filepath)
  local file = io.open(filepath, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()

  local fm = {}
  local in_fm = false
  for line in content:gmatch('[^\n]+') do
    if line == '---' then
      if in_fm then break end
      in_fm = true
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
      fm.filepath = filepath
      table.insert(shots, fm)
    end
  end
  handle:close()
  table.sort(shots, function(a, b) return (a.time or 0) > (b.time or 0) end)
  return shots
end

-- Get time period boundaries
local function get_time_boundaries()
  local today = os.time({ year = os.date('%Y'), month = os.date('%m'), day = os.date('%d'), hour = 0 })
  return {
    now = os.time(), today = today,
    week = today - (tonumber(os.date('%w')) * 86400),
    month = os.time({ year = os.date('%Y'), month = os.date('%m'), day = 1, hour = 0 }),
    year = os.time({ year = os.date('%Y'), month = 1, day = 1, hour = 0 }),
  }
end

-- Calculate statistics from shots
local function calculate_stats(shots)
  local bounds = get_time_boundaries()
  local stats = {
    total = #shots, today = 0, this_week = 0, this_month = 0, this_year = 0,
    by_project = {}, total_chars = 0, total_words = 0, total_sentences = 0, time_diffs = {},
  }

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

    if prev_time and t > 0 then table.insert(stats.time_diffs, prev_time - t) end
    prev_time = t
  end
  return stats
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
  add('')
  add('## Shot Counts')
  add('')
  add(string.format('- **Total**: %d shots', stats.total))
  add(string.format('- **Today**: %d', stats.today))
  add(string.format('- **This Week**: %d', stats.this_week))
  add(string.format('- **This Month**: %d', stats.this_month))
  add(string.format('- **This Year**: %d', stats.this_year))
  add('')

  if not project_filter then
    add('## Shots by Project')
    add('')
    local projects = {}
    for repo, count in pairs(stats.by_project) do table.insert(projects, { repo = repo, count = count }) end
    table.sort(projects, function(a, b) return a.count > b.count end)
    for _, p in ipairs(projects) do add(string.format('- **%s**: %d shots', p.repo, p.count)) end
    add('')
  end

  add('## Averages')
  add('')
  if stats.total > 0 then
    add(string.format('- **Chars/shot**: %.0f', stats.total_chars / stats.total))
    add(string.format('- **Words/shot**: %.0f', stats.total_words / stats.total))
    add(string.format('- **Sentences/shot**: %.1f', stats.total_sentences / stats.total))
  end

  if #stats.time_diffs > 0 then
    local sum = 0
    for _, d in ipairs(stats.time_diffs) do sum = sum + d end
    add(string.format('- **Avg time between shots**: %s', format_duration(sum / #stats.time_diffs)))
  end
  add('')
  add('---')
  add(string.format('*Generated: %s*', os.date('%Y-%m-%d %H:%M:%S')))
  return lines
end

-- Show analytics in a new buffer
function M.show(project_filter)
  local lines = M.generate_report(project_filter)
  vim.cmd('enew')
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile, vim.bo.filetype = 'nofile', 'wipe', false, 'markdown'
  local title = project_filter and ('Shooter Analytics - ' .. project_filter) or 'Shooter Analytics (Global)'
  vim.api.nvim_buf_set_name(0, title)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
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

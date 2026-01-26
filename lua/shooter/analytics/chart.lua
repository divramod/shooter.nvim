-- Analytics bar chart generation
local M = {}

-- Get start of day (midnight) for a timestamp
local function get_day_start(timestamp)
  local d = os.date('*t', timestamp)
  return os.time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

-- Get shots per day for last N days with item breakdown (repos or shotfiles)
-- is_project: if true, track by shotfile; if false, track by repo
function M.get_daily_data(shots, days, is_project)
  local today_start = get_day_start(os.time())
  local data = {}
  for i = 0, days - 1 do data[i] = { count = 0, items = {} } end
  for _, shot in ipairs(shots) do
    local t = shot.time or 0
    if t > 0 then
      local shot_day_start = get_day_start(t)
      local days_ago = math.floor((today_start - shot_day_start) / 86400)
      if days_ago >= 0 and days_ago < days then
        data[days_ago].count = data[days_ago].count + 1
        local item
        if is_project then
          -- For project analytics: track by shotfile (source filename without extension)
          item = shot.source and shot.source:match('([^/]+)%.md$') or 'unknown'
        else
          -- For global analytics: track by repo
          item = shot.repo and shot.repo:match('[^/]+$') or 'unknown'
        end
        data[days_ago].items[item] = (data[days_ago].items[item] or 0) + 1
      end
    end
  end
  return data
end

-- Get top N items from a count table
local function get_top_items(item_counts, n)
  local items = {}
  for name, count in pairs(item_counts) do table.insert(items, { name = name, count = count }) end
  table.sort(items, function(a, b) return a.count > b.count end)
  local result = {}
  for i = 1, math.min(n, #items) do result[i] = items[i] end
  return result
end

-- Generate ASCII bar chart for daily shots (last 30 days)
-- is_project: if true, show shotfiles; if false, show repos
function M.generate_bar_chart(shots, days, is_project)
  local data = M.get_daily_data(shots, days, is_project)
  local max_count, total = 0, 0
  for i = 0, days - 1 do
    if data[i].count > max_count then max_count = data[i].count end
    total = total + data[i].count
  end
  if max_count == 0 then return { 'No shots in the last ' .. days .. ' days' } end

  local avg = total / days
  local lines, bar_width = {}, 30
  table.insert(lines, string.format('Last %d days | max: %d | avg: %.1f shots/day', days, max_count, avg))
  table.insert(lines, '')
  -- Show last 14 days with labels (most recent first)
  for i = 0, math.min(days - 1, 13) do
    local date = os.date('%m/%d', os.time() - i * 86400)
    local count = data[i].count
    local bar_len = count > 0 and math.max(1, math.floor((count / max_count) * bar_width)) or 0
    local bar = string.rep('█', bar_len) .. string.rep('░', bar_width - bar_len)
    -- Build top 3 items string (repos for global, shotfiles for project)
    local top_items = get_top_items(data[i].items, 3)
    local item_str = ''
    if #top_items > 0 then
      local parts = {}
      for _, r in ipairs(top_items) do table.insert(parts, r.name .. ':' .. r.count) end
      item_str = ' (' .. table.concat(parts, ', ') .. ')'
    end
    table.insert(lines, string.format('%s │%s│ %d%s', date, bar, count, item_str))
  end
  return lines
end

return M

-- Time boundaries + stats aggregation + path map.
-- Pulled out of shooter/analytics/data.lua during plan 0001 phase 004 T007.

local M = {}

function M.get_time_boundaries()
  local today = os.time({ year = os.date('%Y'), month = os.date('%m'), day = os.date('%d'), hour = 0 })
  return {
    now = os.time(),
    today = today,
    week = today - (tonumber(os.date('%w')) * 86400),
    month = os.time({ year = os.date('%Y'), month = os.date('%m'), day = 1, hour = 0 }),
    year = os.time({ year = os.date('%Y'), month = 1, day = 1, hour = 0 }),
  }
end

function M.calculate_stats(shots)
  local bounds = M.get_time_boundaries()
  local stats = {
    total = #shots, today = 0, this_week = 0, this_month = 0, this_year = 0,
    by_project = {}, total_chars = 0, total_words = 0, total_sentences = 0, time_diffs = {},
    by_file = { today = {}, week = {}, month = {}, year = {}, alltime = {} },
    longest_chars = nil, shortest_chars = nil,
    longest_words = nil, shortest_words = nil,
    longest_sentences = nil, shortest_sentences = nil,
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

function M.build_path_map(shots)
  local map = {}
  for _, shot in ipairs(shots) do
    if shot.source then
      local short = shot.source:match('[^/]+$') or shot.source
      if not map[short] then map[short] = shot.source end
    end
  end
  return map
end

return M

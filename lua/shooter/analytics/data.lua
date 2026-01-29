-- Analytics data gathering from shotfiles
-- Scans executed shots (## x shot N (YYYY-MM-DD HH:MM:SS)) directly from shotfiles
local M = {}
local utils = require('shooter.utils')
local config = require('shooter.config')

-- Parse executed shot header: ## x shot N (YYYY-MM-DD HH:MM:SS)
-- Returns: shot_num, timestamp_str, timestamp_epoch
function M.parse_executed_shot_header(line)
  local num, date = line:match('^##%s+x%s+shot%s+(%d+)%s+%((.-)%)%s*$')
  if not num then return nil end
  local y, m, d, h, min, s = date:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)')
  local epoch = y and os.time({ year = y, month = m, day = d, hour = h, min = min, sec = s }) or 0
  return tonumber(num), date, epoch
end

-- Extract shot content between header_line and next_header_line (or end_line)
-- Returns: content string, char count, word count, sentence count
function M.get_shot_metrics(lines, start_idx, end_idx)
  local content = {}
  for i = start_idx, end_idx do
    if lines[i] then table.insert(content, lines[i]) end
  end
  local body = table.concat(content, '\n')
  local chars = #body
  local words = select(2, body:gsub('%S+', '')) or 0
  local sentences = select(2, body:gsub('[.!?]', '')) or 0
  return body, chars, words, sentences
end

-- Parse all executed shots from a single shotfile
-- Returns array of shot info tables
function M.parse_shotfile(filepath)
  local file = io.open(filepath, 'r')
  if not file then return {} end
  local content = file:read('*a')
  file:close()

  local lines = {}
  for line in content:gmatch('[^\n]*') do
    table.insert(lines, line)
  end

  local shots = {}
  local shot_pattern = config.get('patterns.executed_shot_header')
  local i = 1
  while i <= #lines do
    local line = lines[i]
    if line:match(shot_pattern) then
      local shot_num, timestamp, epoch = M.parse_executed_shot_header(line)
      if shot_num then
        -- Find end of this shot (next shot header or end of file)
        local shot_end = #lines
        for j = i + 1, #lines do
          if lines[j]:match('^##%s+x?%s*shot') then
            shot_end = j - 1
            break
          end
        end
        -- Get content metrics
        local _, chars, words, sents = M.get_shot_metrics(lines, i + 1, shot_end)
        table.insert(shots, {
          shot = shot_num,
          timestamp = timestamp,
          time = epoch,
          source = filepath,
          chars = chars,
          words = words,
          sentences = sents,
        })
        i = shot_end + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  return shots
end

-- Get git remote info for determining repo name
-- Returns: user, repo or nil
function M.get_git_remote_info(filepath)
  local cmd
  if filepath then
    local dir = utils.get_dirname(filepath)
    cmd = string.format('git -C "%s" remote get-url origin 2>/dev/null', dir)
  else
    cmd = 'git remote get-url origin 2>/dev/null'
  end
  local result = utils.system(cmd)
  if not result or result == '' then return nil, nil end
  result = utils.trim(result)
  -- Parse git@github.com:user/repo.git
  local user, repo = result:match('git@[^:]+:([^/]+)/(.+)%.git$')
  if user and repo then return user, repo end
  -- Parse https://github.com/user/repo.git
  user, repo = result:match('https?://[^/]+/([^/]+)/(.+)%.git$')
  if user and repo then return user, repo end
  -- Fallback without .git suffix
  user, repo = result:match('git@[^:]+:([^/]+)/(.+)$')
  if user and repo then return user, repo end
  user, repo = result:match('https?://[^/]+/([^/]+)/(.+)$')
  return user, repo
end

-- Detect project from filepath (for mono-repos with projects/ folder)
function M.detect_project_from_path(filepath)
  if not filepath then return nil end
  local project = filepath:match('/projects/([^/]+)/')
  return project
end

-- Get all configured repos from shooter config
function M.get_all_repo_paths()
  local repos_config = require('shooter.config')
  local repos = {}
  local seen = {}

  -- Add current repo
  local git_root = utils.system('git rev-parse --show-toplevel 2>/dev/null')
  if git_root and git_root ~= '' then
    git_root = utils.trim(git_root)
    if not seen[git_root] then
      seen[git_root] = true
      table.insert(repos, git_root)
    end
  end

  -- Add direct paths from config
  local direct_paths = repos_config.get('repos.direct_paths') or {}
  for _, path in ipairs(direct_paths) do
    local expanded = utils.expand_path(path)
    if not seen[expanded] and utils.dir_exists(expanded .. '/.git') then
      seen[expanded] = true
      table.insert(repos, expanded)
    end
  end

  -- Search directories for git repos
  local search_dirs = repos_config.get('repos.search_dirs') or {}
  for _, dir in ipairs(search_dirs) do
    local expanded_dir = utils.expand_path(dir)
    if utils.dir_exists(expanded_dir) then
      local handle = io.popen('ls -d "' .. expanded_dir .. '"/*/ 2>/dev/null')
      if handle then
        for subdir in handle:lines() do
          subdir = subdir:gsub('/$', '')
          if not seen[subdir] and utils.dir_exists(subdir .. '/.git') then
            seen[subdir] = true
            table.insert(repos, subdir)
          end
        end
        handle:close()
      end
    end
  end

  return repos
end

-- Get all executed shots from all shotfiles in all configured repos
function M.get_all_shots(project_filter)
  local shots = {}
  local repos = M.get_all_repo_paths()

  for _, repo_path in ipairs(repos) do
    local user, repo = M.get_git_remote_info(repo_path)
    if not user then
      user, repo = 'local', utils.get_basename(repo_path)
    end
    local repo_name = user .. '/' .. repo

    -- Find all .md files in plans/prompts and subprojects
    local prompts_dir = repo_path .. '/plans/prompts'
    local handle = io.popen('find "' .. prompts_dir .. '" -name "*.md" -type f 2>/dev/null')
    if handle then
      for filepath in handle:lines() do
        local project = M.detect_project_from_path(filepath)
        -- Apply project filter if specified
        if not project_filter or repo_name:find(project_filter, 1, true) then
          local file_shots = M.parse_shotfile(filepath)
          for _, shot in ipairs(file_shots) do
            shot.repo = repo_name
            shot.project = project
            table.insert(shots, shot)
          end
        end
      end
      handle:close()
    end

    -- Also check projects/ subdirectories
    local projects_dir = repo_path .. '/projects'
    if utils.dir_exists(projects_dir) then
      handle = io.popen('find "' .. projects_dir .. '" -path "*/plans/prompts/*.md" -type f 2>/dev/null')
      if handle then
        for filepath in handle:lines() do
          local project = M.detect_project_from_path(filepath)
          if not project_filter or repo_name:find(project_filter, 1, true) then
            local file_shots = M.parse_shotfile(filepath)
            for _, shot in ipairs(file_shots) do
              shot.repo = repo_name
              shot.project = project
              table.insert(shots, shot)
            end
          end
        end
        handle:close()
      end
    end
  end

  -- Sort by timestamp (newest first)
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
  end
  return map
end

return M

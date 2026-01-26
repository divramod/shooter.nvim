-- History audit module for shooter.nvim
-- Audits and fixes history files, missing dates, and missing history entries

local utils = require('shooter.utils')
local sync = require('shooter.history.sync')
local config = require('shooter.config')

local M = {}

-- Parse a done shot header, returns shot_num, date (or nil)
function M.parse_done_shot(line)
  local num, date = line:match('^##%s+x%s+shot%s+(%d+)%s+%((.-)%)%s*$')
  if num then return tonumber(num), date end
  num = line:match('^##%s+x%s+shot%s+(%d+)%s*$')
  return num and tonumber(num) or nil, nil
end

-- Subtract one minute from a date string
function M.subtract_minute(date_str)
  local y, mo, d, h, mi, s = date_str:match('(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)')
  if not y then return date_str end
  local time = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) - 60
  return os.date('%Y-%m-%d %H:%M:%S', time)
end

-- Get shot content from file (between this header and next ## header)
function M.get_shot_content(lines, start_idx)
  local content = {}
  for i = start_idx + 1, #lines do
    if lines[i]:match('^##%s+') then break end
    table.insert(content, lines[i])
  end
  while #content > 0 and content[1] == '' do table.remove(content, 1) end
  while #content > 0 and content[#content] == '' do table.remove(content) end
  return table.concat(content, '\n')
end

-- Fix shots missing dates in a file. Returns count of fixed shots
function M.fix_shots_missing_dates(filepath, do_fix)
  local content = utils.read_file(filepath)
  if not content then return 0 end

  local lines = vim.split(content, '\n', { plain = true })
  local shots, fixed = {}, 0

  for i, line in ipairs(lines) do
    local num, date = M.parse_done_shot(line)
    if num then table.insert(shots, { idx = i, num = num, date = date }) end
  end

  for i, shot in ipairs(shots) do
    if not shot.date then
      local derived_date
      for j = i + 1, #shots do
        if shots[j].date then derived_date = M.subtract_minute(shots[j].date); break end
      end
      if not derived_date then
        local stat = vim.loop.fs_stat(filepath)
        derived_date = os.date('%Y-%m-%d %H:%M:%S', stat and stat.mtime.sec or os.time())
      end
      if do_fix then lines[shot.idx] = string.format('## x shot %d (%s)', shot.num, derived_date) end
      shot.date = derived_date
      fixed = fixed + 1
    end
  end

  if do_fix and fixed > 0 then utils.write_file(filepath, table.concat(lines, '\n')) end
  return fixed, shots
end

-- Find done shots without history files
function M.find_missing_history(filepath)
  local content = utils.read_file(filepath)
  if not content then return {} end

  local lines, missing = vim.split(content, '\n', { plain = true }), {}
  for i, line in ipairs(lines) do
    local num, date = M.parse_done_shot(line)
    if num and date and not sync.history_exists_for_shot(filepath, num) then
      table.insert(missing, { number = num, date = date, content = M.get_shot_content(lines, i), source = filepath })
    end
  end
  return missing
end

-- Create a missing history file
function M.create_history_file(shot_data)
  local history = require('shooter.history')
  local user, repo = history.get_git_remote_info()
  if not user then user, repo = 'local', utils.get_basename(utils.cwd()) end

  local project = history.detect_project_from_path(shot_data.source)
  local ts = shot_data.date:gsub('%-', ''):gsub(' ', '_'):gsub(':', '')
  local _, dir_path = history.build_history_path(user, repo, utils.get_filename(shot_data.source), shot_data.number, ts, project)

  utils.ensure_dir(dir_path)
  local filepath = dir_path .. string.format('/shot-%04d-%s.md', shot_data.number, ts)
  local content = string.format(
    "---\nshot: %d\nsource: %s\nrepo: %s/%s\ntimestamp: %s\n---\n\n# Shot Content\n\n%s\n\n# Full Message Sent\n\n<!-- Reconstructed -->\n%s\n",
    shot_data.number, shot_data.source, user, repo, shot_data.date, shot_data.content, shot_data.content)
  return utils.write_file(filepath, content)
end

-- Get all prompt files from configured repos + current repo
function M.get_all_repos_prompt_files()
  local all_files, repos_config = {}, config.get('repos') or {}

  local function add_prompts(base_path)
    local prompts = base_path .. '/plans/prompts'
    if utils.dir_exists(prompts) then
      vim.list_extend(all_files, vim.fn.globpath(prompts, '**/*.md', false, true))
    end
  end

  for _, dir in ipairs(repos_config.search_dirs or {}) do
    local expanded = utils.expand_path(dir)
    if utils.dir_exists(expanded) then
      for _, repo in ipairs(vim.fn.globpath(expanded, '*', false, true)) do add_prompts(repo) end
    end
  end

  for _, repo in ipairs(repos_config.direct_paths or {}) do add_prompts(utils.expand_path(repo)) end

  local git_root = require('shooter.core.files').get_git_root()
  if git_root then add_prompts(git_root) end

  return all_files
end

-- Main audit function
function M.run(opts)
  opts = opts or {}
  local do_fix = opts.fix or false
  local stats = { dates_fixed = 0, history_created = 0, files_checked = 0 }

  for _, filepath in ipairs(M.get_all_repos_prompt_files()) do
    stats.files_checked = stats.files_checked + 1
    stats.dates_fixed = stats.dates_fixed + M.fix_shots_missing_dates(filepath, do_fix)

    for _, shot_data in ipairs(M.find_missing_history(filepath)) do
      if do_fix then
        if M.create_history_file(shot_data) then stats.history_created = stats.history_created + 1 end
      else
        stats.history_created = stats.history_created + 1
      end
    end
  end

  local mode = do_fix and 'Fixed' or 'Found'
  local parts = { stats.files_checked .. ' files checked' }
  if stats.dates_fixed > 0 then table.insert(parts, stats.dates_fixed .. ' shots missing dates') end
  if stats.history_created > 0 then table.insert(parts, stats.history_created .. ' missing history entries') end
  utils.notify('HistoryAudit (' .. mode .. '): ' .. table.concat(parts, ', '), vim.log.levels.INFO)
  return stats
end

return M

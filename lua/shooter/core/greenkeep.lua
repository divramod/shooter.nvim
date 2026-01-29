-- Greenkeep module for shooter.nvim
-- Migrates old formats: dates, headers, and filenames

local utils = require('shooter.utils')
local files = require('shooter.core.files')

local M = {}

-- Patterns
local OLD_DATE_PATTERN = '%((20%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)%)'
local OLD_HEADER_PATTERN = '^#%s+(%d%d%d%d%-%d%d%-%d%d)%s+%-%s+(.+)$'
local OLD_FILENAME_PATTERN1 = '^(%d%d%d%d%d%d%d%d)_(%d%d%d%d)_(.+)%.md$'  -- 20260118_2338_title.md
local OLD_FILENAME_PATTERN2 = '^(%d%d%d%d%-%d%d%-%d%d)_(.+)%.md$'          -- 2026-01-18_title.md

-- Convert shot date format
function M.convert_date(year, month, day, hour, min)
  return string.format('(%s-%s-%s %s:%s:00)', year, month, day, hour, min)
end

-- Slugify a title (lowercase, replace spaces with dashes)
function M.slugify(title)
  return title:lower():gsub('%s+', '-'):gsub('[^%w%-]', '')
end

-- Extract slug from old filename pattern
function M.extract_slug_from_filename(filename)
  local _, _, slug = filename:match(OLD_FILENAME_PATTERN1)
  if slug then return slug end
  _, slug = filename:match(OLD_FILENAME_PATTERN2)
  return slug
end

-- Process file header line
function M.process_header(line)
  local date, title = line:match(OLD_HEADER_PATTERN)
  if date and title then
    return '# ' .. M.slugify(title), true
  end
  return line, false
end

-- Process shot date line
function M.process_shot_date(line)
  if not line:match('^##%s+x%s+shot') then return line, false end
  if not line:match(OLD_DATE_PATTERN) then return line, false end
  local new_line = line:gsub(OLD_DATE_PATTERN, function(y, m, d, h, min)
    return M.convert_date(y, m, d, h, min)
  end)
  return new_line, new_line ~= line
end

-- Process file content (dates and header)
function M.process_file_content(filepath)
  local content, err = utils.read_file(filepath)
  if not content then return 0, false, err end

  local lines = vim.split(content, '\n', { plain = true })
  local shots_updated, header_updated = 0, false

  for i, line in ipairs(lines) do
    if i == 1 then
      local new_line, updated = M.process_header(line)
      if updated then lines[1], header_updated = new_line, true end
    end
    local new_line, updated = M.process_shot_date(line)
    if updated then lines[i], shots_updated = new_line, shots_updated + 1 end
  end

  if shots_updated > 0 or header_updated then
    local success, write_err = utils.write_file(filepath, table.concat(lines, '\n'))
    if not success then return 0, false, write_err end
  end

  return shots_updated, header_updated, nil
end

-- Rename file if it has old naming pattern
function M.rename_file_if_needed(filepath)
  local dir = vim.fn.fnamemodify(filepath, ':h')
  local filename = vim.fn.fnamemodify(filepath, ':t')
  local slug = M.extract_slug_from_filename(filename)
  if not slug then return filepath, false end

  local new_path = dir .. '/' .. slug .. '.md'
  if vim.fn.filereadable(new_path) == 1 then return filepath, false end

  local ok = os.rename(filepath, new_path)
  if not ok then return filepath, false end

  return new_path, true
end

-- Get all prompt files
function M.get_all_prompt_files()
  local git_root = files.get_git_root()
  if not git_root then return {} end
  local prompts_dir = git_root .. '/plans/prompts'
  if not utils.dir_exists(prompts_dir) then return {} end
  return vim.fn.globpath(prompts_dir, '**/*.md', false, true)
end

-- Main run function
function M.run()
  local stats = { shots = 0, headers = 0, files_renamed = 0 }
  local current_file = vim.fn.expand('%:p')
  local new_current_file = current_file

  -- Process prompt files
  for _, filepath in ipairs(M.get_all_prompt_files()) do
    local shots, header_updated, _ = M.process_file_content(filepath)
    stats.shots = stats.shots + shots
    if header_updated then stats.headers = stats.headers + 1 end

    local new_path, renamed = M.rename_file_if_needed(filepath)
    if renamed then
      stats.files_renamed = stats.files_renamed + 1
      if filepath == current_file then new_current_file = new_path end
    end
  end

  -- Reload buffer if current file changed
  if new_current_file ~= current_file then
    vim.cmd('edit ' .. new_current_file)
  elseif stats.shots > 0 or stats.headers > 0 then
    vim.cmd('edit')
  end

  -- Report results
  local parts = {}
  if stats.shots > 0 then table.insert(parts, stats.shots .. ' shot date(s)') end
  if stats.headers > 0 then table.insert(parts, stats.headers .. ' header(s)') end
  if stats.files_renamed > 0 then table.insert(parts, stats.files_renamed .. ' file(s) renamed') end

  if #parts == 0 then
    utils.notify('Greenkeep: Nothing to update', vim.log.levels.INFO)
  else
    utils.notify('Greenkeep: Updated ' .. table.concat(parts, ', '), vim.log.levels.INFO)
  end

  return stats
end

return M

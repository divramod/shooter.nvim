-- History file migration for shooter.nvim
-- Migrates old format (shot-XXXX.md) to new format (shot-XXXX-timestamp.md)

local utils = require('shooter.utils')

local M = {}

-- Check if filename is already in new format (with timestamp)
function M.is_new_format(filename)
  return filename:match('^shot%-%d+%-%d%d%d%d%d%d%d%d_%d%d%d%d%d%d%.md$') ~= nil
end

-- Check if filename is in old format (without timestamp)
function M.is_old_format(filename)
  return filename:match('^shot%-[%d%-]+%.md$') ~= nil and not M.is_new_format(filename)
end

-- Extract timestamp from file content and convert to filename format
function M.extract_timestamp_for_filename(content)
  if not content then return nil end
  local ts = content:match('timestamp:%s*(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)')
  if not ts then return nil end
  local y, mo, d, h, mi, s = ts:match('(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)')
  if not y then return nil end
  return string.format('%s%s%s_%s%s%s', y, mo, d, h, mi, s)
end

-- Migrate old history files to new format with timestamps
-- Renames shot-XXXX.md to shot-XXXX-yyyymmdd_hhmmss.md
function M.migrate_history_files()
  local history_dir = utils.expand_path('~/.config/shooter.nvim/history')
  local cmd = string.format('find "%s" -name "shot-*.md" -type f 2>/dev/null', history_dir)
  local result = utils.system(cmd)

  if not result or result == '' then
    return 0, 0
  end

  local migrated, skipped = 0, 0
  for filepath in result:gmatch('[^\n]+') do
    local filename = filepath:match('([^/]+)$')

    if M.is_new_format(filename) then
      skipped = skipped + 1
    elseif M.is_old_format(filename) then
      local content = utils.read_file(filepath)
      local file_ts = M.extract_timestamp_for_filename(content)
      if file_ts then
        local new_filename = filename:gsub('%.md$', '-' .. file_ts .. '.md')
        local new_path = filepath:gsub('[^/]+$', new_filename)
        os.rename(filepath, new_path)
        migrated = migrated + 1
      else
        skipped = skipped + 1
      end
    end
  end
  return migrated, skipped
end

return M

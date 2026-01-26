-- History cleanup module for shooter.nvim
-- Cleans up duplicate history files created by the timestamp bug

local utils = require('shooter.utils')

local M = {}

-- Check if file has YAML frontmatter
function M.has_frontmatter(filepath)
  local content = utils.read_file(filepath)
  if not content then return false end
  return content:match('^%-%-%-\n') ~= nil
end

-- Parse timestamp string (yyyymmdd_hhmmss) to Unix time
local function parse_ts(ts_str)
  local y, mo, d, h, mi, s = ts_str:match('(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)')
  if not y then return nil end
  return os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
end

-- Find and clean duplicate history files (same shot, 1 second apart)
-- The bug created two files per shot: one from save_sendable (no frontmatter)
-- and one from save_shot (with frontmatter), timestamps 1 second apart.
-- Returns: duplicates_count, total_files_checked
function M.cleanup_duplicates(do_fix)
  local base_dir = utils.expand_path('~/.config/shooter.nvim/history')
  if not utils.dir_exists(base_dir) then return 0, 0 end

  -- Find all shot files grouped by directory
  local cmd = string.format('find "%s" -name "shot-*.md" -type f 2>/dev/null', base_dir)
  local result = utils.system(cmd)
  if not result or result == '' then return 0, 0 end

  -- Group files by directory and shot number
  local by_dir_shot = {}
  local total_files = 0
  for file in result:gmatch('[^\n]+') do
    total_files = total_files + 1
    local dir = file:match('(.+)/[^/]+$')
    local shot_num = file:match('/shot%-(%d+)%-')
    if dir and shot_num then
      local key = dir .. '/' .. shot_num
      by_dir_shot[key] = by_dir_shot[key] or {}
      table.insert(by_dir_shot[key], file)
    end
  end

  local deleted = 0
  for _, files in pairs(by_dir_shot) do
    if #files > 1 then
      -- Sort by timestamp (filename)
      table.sort(files)
      -- Check if timestamps are 1 second apart
      for i = 1, #files - 1 do
        local ts1 = files[i]:match('shot%-%d+%-(%d+_%d+)%.md$')
        local ts2 = files[i + 1]:match('shot%-%d+%-(%d+_%d+)%.md$')
        if ts1 and ts2 then
          local time1, time2 = parse_ts(ts1), parse_ts(ts2)
          if time1 and time2 and (time2 - time1) == 1 then
            -- Found duplicate pair - delete the one WITHOUT frontmatter
            local to_delete = M.has_frontmatter(files[i]) and files[i + 1] or files[i]
            local to_keep = M.has_frontmatter(files[i]) and files[i] or files[i + 1]
            -- Prefer keeping the one with frontmatter
            if M.has_frontmatter(to_keep) or not M.has_frontmatter(to_delete) then
              if do_fix then os.remove(to_delete) end
              deleted = deleted + 1
            end
          end
        end
      end
    end
  end

  return deleted, total_files
end

return M

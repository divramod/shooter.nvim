-- Shotfile parsing — header, metrics, file-level.
-- Pulled out of shooter/analytics/data.lua during plan 0001 phase 004 T007.

local config = require('shooter.config')

local M = {}

-- Parse executed shot header: ## x shot N (YYYY-MM-DD HH:MM:SS)
-- Returns: shot_num, timestamp_str, timestamp_epoch
function M.parse_executed_shot_header(line)
  local num, date = line:match('^##%s+x%s+shot%s+(%d+)%s+%((.-)%)')
  if not num then return nil end
  local y, m, d, h, min, s = date:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)')
  local epoch = y and os.time({ year = y, month = m, day = d, hour = h, min = min, sec = s }) or 0
  return tonumber(num), date, epoch
end

-- Extract shot content between header_line and next_header_line (or end_line).
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

-- Parse all executed shots from a single shotfile.
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
        local shot_end = #lines
        for j = i + 1, #lines do
          if lines[j]:match('^##%s+x?%s*shot') then
            shot_end = j - 1
            break
          end
        end
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

return M

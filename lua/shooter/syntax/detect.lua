-- Pure detection helpers used by syntax/apply.lua + syntax/autocmds.lua.
-- Pulled out of shooter/syntax.lua during plan 0001 phase 004 T005.

local M = {}

function M.is_fence_delimiter(line)
  if not line:match('^%s*```') then return false end
  local _, count = line:gsub('```', '')
  return count == 1
end

function M.build_code_block_map(lines)
  local in_block = false
  local map = {}
  for i, line in ipairs(lines) do
    if M.is_fence_delimiter(line) then
      in_block = not in_block
    end
    if in_block then
      map[i] = true
    end
  end
  return map
end

-- Format: "## x shot N <title> (timestamp) @ref"
-- Returns number_end (col after "## x shot N"), title_start, title_end (before metadata)
-- title_start/title_end are nil when there is no title.
function M.split_executed_header(line)
  local _, number_end_pos = line:find('^##%s+x%s+shot%s+[%d%?]+')
  if not number_end_pos then return nil end
  local meta_start = line:find('%s+%(%d%d%d%d%-')
  if not meta_start then
    local title_start = line:find('%S', number_end_pos + 1)
    if title_start then
      return number_end_pos, title_start, #line
    end
    return number_end_pos, nil, nil
  end
  local title_start = line:find('%S', number_end_pos + 1)
  if title_start and title_start < meta_start then
    return number_end_pos, title_start, meta_start
  end
  return number_end_pos, nil, nil
end

function M.is_prompts_file(filepath)
  if filepath:match('^oil://') then return false end
  return filepath:match('docs/shotfiles/.+%.md$') ~= nil
end

return M

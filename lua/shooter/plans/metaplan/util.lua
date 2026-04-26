-- Shared constants + predicates used across the metaplan sub-modules.
-- No deps — every other sub-module requires this.

local M = {}

M.SECTIONS = { 'in progress', 'planned', 'specified', 'next plans', 'done' }
M.AUTO_SECTIONS = { 'in progress', 'planned', 'specified', 'next plans' }
M.TIMESTAMP_TAIL = '%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)$'
M.COMMIT_PATHS = { 'docs/plans' }
M.COMMIT_MSG = 'chore(plans): sync metaplan + plan ideas'
M.SHOT_HEADER = '^##%s+x?%s*shot%s+(%d+)'
M.OPEN_SHOT_HEADER = '^##%s+shot%s+(%d+)'

function M.is_top_entry(line)
  return line:match('^%-%s+') ~= nil
end

function M.is_header(line)
  return line:match('^##%s') ~= nil
end

function M.is_child_line(line)
  return line == '' or line:match('^%s')
end

function M.is_canonical(name)
  for _, s in ipairs(M.SECTIONS) do if s == name then return true end end
  return false
end

function M.is_timestamp_paren(s)
  return type(s) == 'string'
    and s:match('^%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)$') ~= nil
end

return M

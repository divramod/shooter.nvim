-- Picker title builder. Renders session/filter/sort indicators next to a
-- base title for use as the telescope picker prompt_title.
local M = {}

local session = require('shooter.session')
local session_filter = require('shooter.session.filter')
local session_sort = require('shooter.session.sort')

function M.build(base_title)
  local current = session.get_current_session()
  local filter_status = session_filter.get_filter_status(current)
  local sort_status = session_sort.get_sort_status(current)
  local parts = { base_title }
  local indicators = { current.name, filter_status }
  if sort_status ~= 'default' then
    table.insert(indicators, 'sort:' .. sort_status)
  end
  table.insert(parts, '[' .. table.concat(indicators, ' | ') .. ']')
  table.insert(parts, '(?=help)')
  return table.concat(parts, ' ')
end

return M

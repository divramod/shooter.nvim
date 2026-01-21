-- PRD task list for shooter.nvim
-- Telescope picker for plans/prd.json tasks

local utils = require('shooter.utils')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local M = {}

-- Priority icons
local priority_icons = {
  critical = '🔴',
  high = '🟠',
  normal = '🟢',
  low = '⚪',
}

-- Get first line of description (truncated)
local function get_first_line(desc)
  if not desc or desc == '' then return '' end
  local first = desc:match('^([^\n]+)')
  if first and #first > 50 then
    first = first:sub(1, 47) .. '...'
  end
  return first or ''
end

-- Show PRD task list in telescope
function M.list()
  local cwd = vim.fn.getcwd()
  local prd_path = cwd .. '/plans/prd.json'

  if vim.fn.filereadable(prd_path) ~= 1 then
    utils.echo('No prd.json found in plans/')
    return
  end

  local file = io.open(prd_path, 'r')
  if not file then
    utils.echo('Failed to read prd.json')
    return
  end

  local content = file:read('*all')
  file:close()

  local ok, prd = pcall(vim.json.decode, content)
  if not ok or not prd then
    utils.echo('Failed to parse prd.json')
    return
  end

  local all_requirements = prd.requirements or {}
  if #all_requirements == 0 then
    utils.echo('No requirements found in prd.json')
    return
  end

  -- Build phases lookup
  local phases = {}
  if prd.phases then
    for _, phase in ipairs(prd.phases) do
      phases[phase.id] = phase.name
    end
  end

  -- Filter/sort state
  local current_filter = 'all'
  local current_sort = 'id'

  local function get_filtered_sorted()
    local filtered = {}
    for _, req in ipairs(all_requirements) do
      if current_filter == 'all' then
        table.insert(filtered, req)
      elseif current_filter == 'done' and req.passes then
        table.insert(filtered, req)
      elseif current_filter == 'open' and not req.passes then
        table.insert(filtered, req)
      end
    end
    table.sort(filtered, function(a, b)
      if current_sort == 'description' then
        return (a.description or '') < (b.description or '')
      end
      return (a.id or '') < (b.id or '')
    end)
    return filtered
  end

  local function make_entry(req)
    local priority = priority_icons[req.priority] or '?'
    local status = req.passes and '✓' or '○'
    local id = req.id or '?'
    local title = req.title or '(no title)'
    local desc_line = get_first_line(req.description)
    local display = desc_line ~= '' and
      string.format('%s %s [%s] %s | %s', status, priority, id, title, desc_line) or
      string.format('%s %s [%s] %s', status, priority, id, title)
    return { value = req, display = display, ordinal = id .. ' ' .. title }
  end

  local function make_finder()
    return finders.new_table({ results = get_filtered_sorted(), entry_maker = make_entry })
  end

  local function get_title()
    local filter_str = current_filter == 'all' and '' or (' [' .. current_filter .. ']')
    return 'PRD Tasks (' .. (prd.project or 'unknown') .. ')' .. filter_str .. ' (sort:' .. current_sort .. ')'
  end

  pickers.new({}, {
    prompt_title = get_title(),
    layout_strategy = 'horizontal',
    layout_config = { width = 0.95, preview_width = 0.5 },
    finder = make_finder(),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = 'Task Details',
      define_preview = function(self, entry)
        local req = entry.value
        local lines = { '# ' .. (req.title or '(no title)'), '', '**ID:** ' .. (req.id or '?'),
          '**Priority:** ' .. (req.priority or 'normal'),
          '**Status:** ' .. (req.passes and 'Completed ✓' or 'Pending ○') }
        if req.phaseId and phases[req.phaseId] then
          table.insert(lines, '**Phase:** ' .. phases[req.phaseId])
        end
        if req.completedAt then table.insert(lines, '**Completed:** ' .. req.completedAt) end
        if req.completedVersion then table.insert(lines, '**Version:** ' .. req.completedVersion) end
        table.insert(lines, '')
        if req.description and req.description ~= '' then
          table.insert(lines, '## Description')
          table.insert(lines, '')
          for line in req.description:gmatch('[^\n]+') do table.insert(lines, line) end
          table.insert(lines, '')
        end
        if req.acceptanceCriteria and #req.acceptanceCriteria > 0 then
          table.insert(lines, '## Acceptance Criteria')
          table.insert(lines, '')
          for _, c in ipairs(req.acceptanceCriteria) do table.insert(lines, '- [ ] ' .. c) end
          table.insert(lines, '')
        end
        if req.dependencies and #req.dependencies > 0 then
          table.insert(lines, '## Dependencies')
          table.insert(lines, '')
          for _, d in ipairs(req.dependencies) do table.insert(lines, '- ' .. d) end
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local sel = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if sel then utils.echo('Selected: ' .. sel.value.id .. ' - ' .. (sel.value.title or '')) end
      end)
      local function refresh()
        local picker = action_state.get_current_picker(prompt_bufnr)
        picker:refresh(make_finder(), {})
        picker.prompt_border:change_title(get_title())
      end
      map('n', 'fd', function() current_filter = 'done' refresh() utils.echo('Filter: done') end)
      map('n', 'fo', function() current_filter = 'open' refresh() utils.echo('Filter: open') end)
      map('n', 'fa', function() current_filter = 'all' refresh() utils.echo('Filter: all') end)
      map('n', 'sd', function() current_sort = 'description' refresh() utils.echo('Sort: description') end)
      map('n', 'si', function() current_sort = 'id' refresh() utils.echo('Sort: id') end)
      map('n', 'h', function()
        utils.echo('PRD: fd=done fo=open fa=all | sd=sort desc si=sort id | h=help q=close')
      end)
      return true
    end,
  }):find()
end

return M

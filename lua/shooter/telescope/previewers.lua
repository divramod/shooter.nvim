-- Custom previewers for shooter.nvim telescope pickers
local M = {}

local previewers = require('telescope.previewers')

-- Shot previewer - shows shot content in preview window
function M.shot_previewer()
  return previewers.new_buffer_previewer({
    title = "Shot Content",
    define_preview = function(self, entry, status)
      if not entry or not entry.value then return end

      local shot_data = entry.value
      local lines = shot_data.lines

      -- Get shot content from lines
      local shot_lines = {}
      for i = shot_data.start_line, shot_data.end_line do
        table.insert(shot_lines, lines[i])
      end

      -- Display in preview buffer
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, shot_lines)

      -- Set markdown filetype for syntax highlighting
      vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
    end,
  })
end

-- File previewer - shows file content in preview window
function M.file_previewer()
  return previewers.new_buffer_previewer({
    title = "File Preview",
    define_preview = function(self, entry, status)
      if not entry or not entry.path then return end

      local file_path = entry.path

      -- Read file content
      local file = io.open(file_path, 'r')
      if not file then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {'Error: Could not read file'})
        return
      end

      local content = file:read('*a')
      file:close()

      -- Parse into lines
      local file_lines = {}
      for line in content:gmatch('[^\n]*') do
        table.insert(file_lines, line)
      end

      -- Display in preview buffer
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, file_lines)

      -- Set markdown filetype for syntax highlighting
      vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
    end,
  })
end

-- PRD task previewer - shows task details in preview window
function M.prd_task_previewer(prd_data)
  local phases = {}
  if prd_data and prd_data.phases then
    for _, phase in ipairs(prd_data.phases) do
      phases[phase.id] = phase.name
    end
  end

  return previewers.new_buffer_previewer({
    title = 'Task Details',
    define_preview = function(self, entry, status)
      if not entry or not entry.value then return end

      local req = entry.value
      local lines = {}

      -- Header
      table.insert(lines, '# ' .. (req.title or '(no title)'))
      table.insert(lines, '')

      -- Status and metadata
      table.insert(lines, '**ID:** ' .. (req.id or '?'))
      table.insert(lines, '**Priority:** ' .. (req.priority or 'normal'))
      table.insert(lines, '**Status:** ' .. (req.passes and 'Completed ✓' or 'Pending ○'))

      if req.phaseId and phases[req.phaseId] then
        table.insert(lines, '**Phase:** ' .. phases[req.phaseId])
      end

      if req.completedAt then
        table.insert(lines, '**Completed:** ' .. req.completedAt)
      end

      if req.completedVersion then
        table.insert(lines, '**Version:** ' .. req.completedVersion)
      end

      table.insert(lines, '')

      -- Description
      if req.description and req.description ~= '' then
        table.insert(lines, '## Description')
        table.insert(lines, '')
        for line in req.description:gmatch('[^\n]+') do
          table.insert(lines, line)
        end
        table.insert(lines, '')
      end

      -- Acceptance Criteria
      if req.acceptanceCriteria and #req.acceptanceCriteria > 0 then
        table.insert(lines, '## Acceptance Criteria')
        table.insert(lines, '')
        for _, criterion in ipairs(req.acceptanceCriteria) do
          table.insert(lines, '- [ ] ' .. criterion)
        end
        table.insert(lines, '')
      end

      -- Dependencies
      if req.dependencies and #req.dependencies > 0 then
        table.insert(lines, '## Dependencies')
        table.insert(lines, '')
        for _, dep in ipairs(req.dependencies) do
          table.insert(lines, '- ' .. dep)
        end
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.bo[self.state.bufnr].filetype = 'markdown'
    end,
  })
end

return M

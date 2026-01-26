-- Context-aware target resolvers for shooter.nvim
-- Resolves targets based on current context for each namespace

local M = {}

local context = require('shooter.context')

-- Resolve shot target (for Shot namespace commands)
-- Works in: shotfile buffer (cursor), shot picker (selection)
-- Returns: { bufnr, header_line, start_line, end_line } or nil
function M.resolve_shot_target()
  local ctx = context.detect_context()

  -- Context 1: In telescope picker (shot picker)
  if ctx == 'telescope' then
    local sel = context.get_telescope_selection()
    if sel and sel.value then
      local shot_data = sel.value
      -- Shot picker entries have: header_line, start_line, end_line, target_file
      if shot_data.header_line then
        return {
          target_file = shot_data.target_file,
          header_line = shot_data.header_line,
          start_line = shot_data.start_line,
          end_line = shot_data.end_line,
          is_current_file = shot_data.is_current_file,
        }
      end
    end
    return nil
  end

  -- Context 2: In shotfile buffer (cursor position)
  if ctx == 'shotfile' then
    local shots = require('shooter.core.shots')
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local shot = shots.find_current_shot(bufnr, cursor[1])
    if shot then
      return {
        target_file = vim.api.nvim_buf_get_name(bufnr),
        header_line = shot.header_line,
        start_line = shot.start_line,
        end_line = shot.end_line,
        bufnr = bufnr,
        is_current_file = true,
      }
    end
    return nil
  end

  return nil
end

-- Resolve shotfile target (for Shotfile namespace commands)
-- Works in: shotfile buffer (current), shotfile picker (selection), Oil (cursor)
-- Returns: { path } or nil
function M.resolve_shotfile_target()
  local ctx = context.detect_context()

  -- Context 1: In telescope picker (shotfile picker)
  if ctx == 'telescope' then
    local sel = context.get_telescope_selection()
    if sel and sel.path then
      return { path = sel.path }
    end
    return nil
  end

  -- Context 2: In Oil buffer
  if ctx == 'oil' then
    local entry = context.get_oil_cursor_entry()
    if entry and entry.path then
      -- Only return if it's a file (not directory) or if it's in prompts
      if entry.type == 'file' or context.is_shotfile(entry.path) then
        return { path = entry.path }
      end
    end
    return nil
  end

  -- Context 3: In shotfile buffer itself
  if ctx == 'shotfile' then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= '' then
      return { path = bufname }
    end
    return nil
  end

  -- Context 4: In any buffer with a file
  if ctx == 'buffer' then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= '' then
      return { path = bufname }
    end
  end

  return nil
end

-- Resolve subproject target (for Subproject namespace commands)
-- Works in: project file, project picker, Oil (projects/ folder)
-- Returns: { name, path } or nil
function M.resolve_subproject_target()
  local ctx = context.detect_context()
  local files = require('shooter.core.files')
  local git_root = files.get_git_root()
  if not git_root then return nil end

  -- Context 1: In telescope picker (project picker)
  if ctx == 'telescope' then
    local sel = context.get_telescope_selection()
    if sel and sel.value then
      -- Project picker entries have project name
      local project = sel.value.project or sel.value.name or sel.value
      if type(project) == 'string' then
        return {
          name = project,
          path = git_root .. '/projects/' .. project,
        }
      end
    end
    return nil
  end

  -- Context 2: In Oil buffer (check if in projects/ folder)
  if ctx == 'oil' then
    local entry = context.get_oil_cursor_entry()
    if entry and entry.path then
      -- Check if we're in projects/ folder
      local project = entry.path:match('/projects/([^/]+)')
      if project then
        return {
          name = project,
          path = git_root .. '/projects/' .. project,
        }
      end
    end
    return nil
  end

  -- Context 3: Detect from current working directory
  local project = context.get_current_project()
  if project then
    return {
      name = project,
      path = git_root .. '/projects/' .. project,
    }
  end

  return nil
end

-- Resolve context for generic file operations
-- Works in any context, returns the most appropriate file path
function M.resolve_file_target()
  local ctx = context.detect_context()

  if ctx == 'telescope' then
    local sel = context.get_telescope_selection()
    if sel and sel.path then
      return sel.path
    end
  elseif ctx == 'oil' then
    local entry = context.get_oil_cursor_entry()
    if entry then
      return entry.path
    end
  else
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= '' then
      return bufname
    end
  end

  return nil
end

-- Helper: Check if we can perform shot operations
function M.can_perform_shot_ops()
  local ctx = context.detect_context()
  return ctx == 'telescope' or ctx == 'shotfile'
end

-- Helper: Check if we can perform shotfile operations
function M.can_perform_shotfile_ops()
  local ctx = context.detect_context()
  return ctx == 'telescope' or ctx == 'oil' or ctx == 'shotfile' or ctx == 'buffer'
end

-- Get a descriptive context name for notifications
function M.get_context_name()
  local ctx = context.detect_context()
  local names = {
    telescope = 'picker',
    oil = 'Oil',
    shotfile = 'shotfile',
    buffer = 'buffer',
  }
  return names[ctx] or 'unknown'
end

return M

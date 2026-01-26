-- Context detection for shooter.nvim
-- Detects current context to enable context-aware command dispatch

local M = {}

-- Check if current buffer is a telescope picker
function M.is_telescope_picker()
  local bufname = vim.api.nvim_buf_get_name(0)
  local filetype = vim.bo.filetype
  return filetype == 'TelescopePrompt' or filetype == 'TelescopeResults'
    or bufname:match('%[Telescope%]')
end

-- Check if current buffer is an Oil buffer
function M.is_oil_buffer()
  local bufname = vim.api.nvim_buf_get_name(0)
  return bufname:match('^oil://') ~= nil
end

-- Check if a filepath is a shotfile (in prompts folder)
function M.is_shotfile(filepath)
  if not filepath or filepath == '' then return false end
  local config = require('shooter.config')
  local prompts_dir = config.get('paths.prompts_dir')
  if prompts_dir:match('^%./') then
    prompts_dir = prompts_dir:sub(3)
  end
  -- Check if path contains prompts directory
  return filepath:match('/' .. vim.pesc(prompts_dir) .. '/') ~= nil
    or filepath:match('/' .. vim.pesc(prompts_dir) .. '$') ~= nil
    or filepath:match('/prompts/') ~= nil
end

-- Check if current buffer is a shotfile
function M.is_in_shotfile()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == '' then return false end
  return M.is_shotfile(bufname)
end

-- Get current buffer path (handles Oil buffers)
function M.get_current_path()
  local bufname = vim.api.nvim_buf_get_name(0)
  if M.is_oil_buffer() then
    local ok, oil = pcall(require, 'oil')
    if ok then
      local entry = oil.get_cursor_entry()
      if entry then
        local dir = oil.get_current_dir()
        if dir and entry.name then
          return dir .. entry.name
        end
      end
    end
    return nil
  end
  return bufname ~= '' and bufname or nil
end

-- Get Oil entry under cursor (if in Oil buffer)
function M.get_oil_cursor_entry()
  if not M.is_oil_buffer() then return nil end
  local ok, oil = pcall(require, 'oil')
  if not ok then return nil end
  local entry = oil.get_cursor_entry()
  if not entry then return nil end
  local dir = oil.get_current_dir()
  if dir and entry.name then
    return {
      path = dir .. entry.name,
      name = entry.name,
      type = entry.type,
    }
  end
  return nil
end

-- Get telescope selection (if in telescope picker)
function M.get_telescope_selection()
  if not M.is_telescope_picker() then return nil end
  local ok, action_state = pcall(require, 'telescope.actions.state')
  if not ok then return nil end
  local entry = action_state.get_selected_entry()
  if not entry then return nil end
  return {
    value = entry.value,
    path = entry.value and entry.value.path or entry.path,
    display = entry.display,
  }
end

-- Detect current context type
-- Returns: 'telescope', 'oil', 'shotfile', 'buffer', or nil
function M.detect_context()
  if M.is_telescope_picker() then
    return 'telescope'
  elseif M.is_oil_buffer() then
    return 'oil'
  elseif M.is_in_shotfile() then
    return 'shotfile'
  else
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= '' then
      return 'buffer'
    end
  end
  return nil
end

-- Check if we're in a projects/ folder
function M.is_in_projects_folder()
  local cwd = vim.fn.getcwd()
  return cwd:match('/projects/[^/]+') ~= nil
end

-- Get current project name from path
function M.get_current_project()
  local cwd = vim.fn.getcwd()
  local project = cwd:match('/projects/([^/]+)')
  return project
end

return M

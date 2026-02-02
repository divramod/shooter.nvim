-- Telescope picker for toggle panes
-- Shows configured panes with preview of commands

local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local config_panes = require('shooter.tmux.config_panes')
local toggle_panes = require('shooter.tmux.toggle_panes')
local hidden_session = require('shooter.tmux.hidden_session')
local utils = require('shooter.utils')

-- Get pane history/content
---@param pane_target string Pane ID or session:window target
---@return string[] lines
local function get_pane_history(pane_target)
  local handle = io.popen(string.format(
    "tmux capture-pane -p -t '%s' 2>/dev/null",
    pane_target
  ))
  if not handle then
    return { '(unable to capture pane content)' }
  end
  local content = handle:read('*a')
  handle:close()

  local lines = {}
  for line in content:gmatch('[^\n]*') do
    lines[#lines + 1] = line
  end
  return lines
end

-- Create previewer that shows pane history or YAML config
local function create_previewer()
  return previewers.new_buffer_previewer({
    title = 'Pane Preview',
    define_preview = function(self, entry)
      local pane = entry.value
      local pane_state = toggle_panes.get_state(pane.name)
      local lines = {}
      local filetype = 'yaml'

      -- Check if pane is visible - show history
      if pane_state and pane_state.pane_id then
        lines = get_pane_history(pane_state.pane_id)
        filetype = 'text'
      -- Check if pane is hidden - show history from hidden session
      elseif toggle_panes.is_hidden(pane.name) then
        local folder = (pane_state and pane_state.folder) or hidden_session.get_folder_name()
        local window_name = hidden_session.get_window_name(folder, pane.name)
        local window_target = hidden_session.find_window(window_name)
        if window_target then
          lines = get_pane_history(window_target)
          filetype = 'text'
        end
      end

      -- If no history, show YAML config
      if #lines == 0 or (#lines == 1 and lines[1] == '') then
        lines = {}
        lines[#lines + 1] = '# Pane not created yet'
        lines[#lines + 1] = ''
        lines[#lines + 1] = '- name: ' .. pane.name
        if pane.height then
          lines[#lines + 1] = '  height: ' .. pane.height
        end
        if pane.focus ~= nil then
          lines[#lines + 1] = '  focus: ' .. tostring(pane.focus)
        end
        if pane.commands and #pane.commands > 0 then
          lines[#lines + 1] = '  commands:'
          for _, cmd in ipairs(pane.commands) do
            lines[#lines + 1] = '  - ' .. cmd
          end
        end
        filetype = 'yaml'
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', filetype)
    end,
  })
end

-- Build display string for a pane entry
---@param pane table Pane config
---@return string
local function build_display(pane)
  local status = ''
  if toggle_panes.is_visible(pane.name) then
    status = ' [visible]'
  elseif toggle_panes.is_hidden(pane.name) then
    status = ' [hidden]'
  end
  return pane.name .. status
end

-- Show picker with context-aware actions
-- If a visible pane is selected, offer hide/switch options
-- If no pane is visible or hidden pane selected, show it
function M.show_picker()
  local config = config_panes.get_current()

  if not config or #config == 0 then
    utils.notify('No panes configured in .shooter.nvim/tmux.yml', vim.log.levels.WARN)
    return
  end

  local visible_panes = toggle_panes.get_visible_panes()

  pickers.new({}, {
    prompt_title = 'Toggle Panes',
    finder = finders.new_table({
      results = config,
      entry_maker = function(pane)
        return {
          value = pane,
          display = build_display(pane),
          ordinal = pane.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = create_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: toggle directly without confirmation
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local pane = selection.value
        actions.close(prompt_bufnr)

        -- Toggle the pane (show if hidden, hide if visible)
        toggle_panes.toggle(pane.name)
      end)

      -- 'h' to hide selected pane
      map('n', 'h', function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        local pane = selection.value
        if toggle_panes.is_visible(pane.name) then
          toggle_panes.hide(pane.name)
          -- Refresh picker
          local picker = action_state.get_current_picker(prompt_bufnr)
          picker:refresh(finders.new_table({
            results = config,
            entry_maker = function(p)
              return {
                value = p,
                display = build_display(p),
                ordinal = p.name,
              }
            end,
          }), { reset_prompt = false })
        else
          utils.notify('Pane "' .. pane.name .. '" is not visible', vim.log.levels.WARN)
        end
      end, { desc = 'Hide pane' })

      -- 's' to show selected pane
      map('n', 's', function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        local pane = selection.value
        if not toggle_panes.is_visible(pane.name) then
          toggle_panes.show(pane.name)
          -- Refresh picker
          local picker = action_state.get_current_picker(prompt_bufnr)
          picker:refresh(finders.new_table({
            results = config,
            entry_maker = function(p)
              return {
                value = p,
                display = build_display(p),
                ordinal = p.name,
              }
            end,
          }), { reset_prompt = false })
        else
          utils.notify('Pane "' .. pane.name .. '" is already visible', vim.log.levels.INFO)
        end
      end, { desc = 'Show pane' })

      -- 'H' to hide all visible panes
      map('n', 'H', function()
        for _, name in ipairs(visible_panes) do
          toggle_panes.hide(name)
        end
        -- Refresh picker
        local picker = action_state.get_current_picker(prompt_bufnr)
        picker:refresh(finders.new_table({
          results = config,
          entry_maker = function(p)
            return {
              value = p,
              display = build_display(p),
              ordinal = p.name,
            }
          end,
        }), { reset_prompt = false })
      end, { desc = 'Hide all panes' })

      return true
    end,
  }):find()
end

return M

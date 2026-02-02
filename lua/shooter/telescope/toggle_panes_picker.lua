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
local utils = require('shooter.utils')

-- Create previewer that shows pane commands
local function create_previewer()
  return previewers.new_buffer_previewer({
    title = 'Pane Commands',
    define_preview = function(self, entry)
      local pane = entry.value
      local lines = {
        '# ' .. pane.name,
        '',
        'Height: ' .. (pane.height or 30) .. '%',
        '',
        '## Commands:',
      }

      if pane.commands and #pane.commands > 0 then
        for _, cmd in ipairs(pane.commands) do
          table.insert(lines, '  ' .. cmd)
        end
      else
        table.insert(lines, '  (no commands)')
      end

      -- Add status
      table.insert(lines, '')
      if toggle_panes.is_visible(pane.name) then
        table.insert(lines, '## Status: VISIBLE')
      elseif toggle_panes.is_hidden(pane.name) then
        table.insert(lines, '## Status: HIDDEN (will restore)')
      else
        table.insert(lines, '## Status: NOT CREATED')
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
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
      -- Default action: toggle
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local pane = selection.value
        actions.close(prompt_bufnr)

        -- If pane is visible, ask what to do
        if toggle_panes.is_visible(pane.name) then
          vim.ui.select(
            { 'Hide this pane', 'Keep visible' },
            { prompt = 'Pane "' .. pane.name .. '" is visible:' },
            function(choice)
              if choice == 'Hide this pane' then
                toggle_panes.hide(pane.name)
              end
            end
          )
        else
          -- Show the pane
          toggle_panes.show(pane.name)
        end
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

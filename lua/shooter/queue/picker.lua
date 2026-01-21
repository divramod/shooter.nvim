-- Queue telescope picker for shooter.nvim
-- Interactive queue viewing and management

local utils = require('shooter.utils')
local config = require('shooter.config')
local queue = require('shooter.queue')

local M = {}

-- Setup telescope picker actions
local function setup_queue_actions(prompt_bufnr, map, queue_data)
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Enter: edit the shot file at the queued shot
  actions.select_default:replace(function()
    local selection = action_state.get_selected_entry()
    actions.close(prompt_bufnr)
    if selection then
      vim.cmd('edit ' .. utils.fnameescape(selection.value.file))
      utils.set_cursor(selection.value.shot_line, 0)
    end
  end)

  -- d: remove from queue
  map('n', 'd', function()
    local selection = action_state.get_selected_entry()
    if selection and queue.remove_from_queue(selection.index) then
      actions.close(prompt_bufnr)
      M.show_queue_picker()
    end
  end)

  -- c: clear entire queue
  map('n', 'c', function()
    actions.close(prompt_bufnr)
    if vim.fn.input('Clear entire queue? (y/n): '):lower() == 'y' then
      queue.clear_queue()
    end
  end)

  -- 1-9: send shot to pane and remove from queue
  for i = 1, (config.get('tmux.max_panes') or 9) do
    map('n', tostring(i), function()
      local selection = action_state.get_selected_entry()
      actions.close(prompt_bufnr)
      if selection then
        local item = selection.value
        vim.cmd('edit ' .. utils.fnameescape(item.file))
        utils.set_cursor(item.shot_line, 0)

        local tmux = require('shooter.tmux.send')
        if tmux and tmux.send_shot then
          tmux.send_shot(i)
        else
          utils.echo('Tmux send module not available')
        end
        queue.remove_from_queue(selection.index)
      end
    end)
  end

  -- p: change pane assignment
  local max_panes = config.get('tmux.max_panes') or 9
  map('n', 'p', function()
    local selection = action_state.get_selected_entry()
    if not selection then return end

    local new_pane = tonumber(vim.fn.input('New pane number (1-' .. max_panes .. '): '))
    if new_pane and new_pane >= 1 and new_pane <= max_panes then
      if queue.update_pane(selection.index, new_pane) then
        actions.close(prompt_bufnr)
        M.show_queue_picker()
      end
    else
      utils.echo('Invalid pane number')
    end
  end)

  -- m: move item in queue
  map('n', 'm', function()
    local selection = action_state.get_selected_entry()
    if not selection then return end

    local to_index = tonumber(vim.fn.input('Move to position: '))
    if to_index and queue.move_item(selection.index, to_index) then
      actions.close(prompt_bufnr)
      M.show_queue_picker()
    else
      utils.echo('Invalid position')
    end
  end)

  return true
end

-- Build telescope entries from queue
local function build_entries(queue_data)
  local entries = {}
  for i, item in ipairs(queue_data) do
    local timestamp = os.date('%Y-%m-%d %H:%M', item.timestamp)
    local display = string.format('[Pane #%d] Shot %s: %s (%s)',
      item.pane, item.shot_number, item.title, timestamp)
    table.insert(entries, { value = item, display = display, ordinal = display, index = i })
  end
  return entries
end

-- Show queue picker with telescope
function M.show_queue_picker()
  local queue_data = queue.get_queue()
  if #queue_data == 0 then
    utils.echo('Queue is empty')
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values

  pickers.new({}, {
    prompt_title = 'Shot Queue',
    layout_strategy = config.get('telescope.layout_strategy'),
    layout_config = config.get('telescope.layout_config'),
    finder = finders.new_table({
      results = build_entries(queue_data),
      entry_maker = function(entry) return entry end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      return setup_queue_actions(prompt_bufnr, map, queue_data)
    end,
  }):find()
end

-- Show help for queue picker
function M.show_help()
  local help_lines = {
    'Shot Queue Picker - Keybindings:',
    '',
    'Enter  - Edit shot file at queued position',
    'd      - Remove shot from queue',
    'c      - Clear entire queue (with confirmation)',
    '1-9    - Send shot to pane and remove from queue',
    'p      - Change pane assignment',
    'm      - Move item to different position',
    'q/Esc  - Close picker',
  }

  vim.notify(table.concat(help_lines, '\n'), vim.log.levels.INFO)
end

return M

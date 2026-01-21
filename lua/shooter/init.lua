-- Main entry point for shooter.nvim
-- Setup function and plugin initialization

local M = {}

-- Store initialization state
M._initialized = false
M._config = nil

-- Setup function - must be called by user to initialize the plugin
function M.setup(user_config)
  if M._initialized then
    vim.notify('shooter.nvim is already initialized', vim.log.levels.WARN)
    return M._config
  end

  -- Merge user config with defaults
  local config = require('shooter.config')
  M._config = config.setup(user_config or {})

  -- Register commands
  M._setup_commands()

  -- Register keymaps (if enabled)
  if M._config.keymaps.enabled then
    M._setup_keymaps()
  end

  M._initialized = true
  return M._config
end

-- Setup user commands
function M._setup_commands()
  -- Shot management commands
  vim.api.nvim_create_user_command('ShooterSendShot', function(opts)
    local tmux = require('shooter.tmux')
    local pane = tonumber(opts.args) or 1
    tmux.send_current_shot(pane)
  end, { nargs = '?', desc = 'Send current shot to Claude pane' })

  vim.api.nvim_create_user_command('ShooterMarkExecuted', function()
    local shots = require('shooter.core.shots')
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local _, _, header_line = shots.find_current_shot(0, cursor_line)
    if header_line then
      shots.mark_shot_executed(0, header_line)
    end
  end, { desc = 'Mark current shot as executed' })

  vim.api.nvim_create_user_command('ShooterNextShot', function()
    local movement = require('shooter.core.movement')
    movement.jump_to_next_shot()
  end, { desc = 'Jump to next shot' })

  vim.api.nvim_create_user_command('ShooterPrevShot', function()
    local movement = require('shooter.core.movement')
    movement.jump_to_prev_shot()
  end, { desc = 'Jump to previous shot' })

  -- File management commands
  vim.api.nvim_create_user_command('ShooterNewFile', function(opts)
    local files = require('shooter.core.files')
    local title = opts.args ~= '' and opts.args or 'New Shot File'
    local path, filename = files.create_file(title)
    if path then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    end
  end, { nargs = '?', desc = 'Create new shooter file' })

  vim.api.nvim_create_user_command('ShooterFindFiles', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files()
    if picker then
      picker:find()
    end
  end, { desc = 'Find shooter files with Telescope' })

  vim.api.nvim_create_user_command('ShooterFindShots', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then
      picker:find()
    end
  end, { desc = 'Find open shots with Telescope' })

  -- Queue management commands
  vim.api.nvim_create_user_command('ShooterQueueAdd', function(opts)
    local queue = require('shooter.queue')
    local pane = tonumber(opts.args) or 1
    queue.add_to_queue(nil, pane)
  end, { nargs = '?', desc = 'Add current shot to queue' })

  vim.api.nvim_create_user_command('ShooterQueueView', function()
    local queue_picker = require('shooter.queue.picker')
    queue_picker.show_queue()
  end, { desc = 'View shot queue' })

  vim.api.nvim_create_user_command('ShooterQueueClear', function()
    local queue = require('shooter.queue')
    queue.clear_queue()
  end, { desc = 'Clear shot queue' })

  vim.api.nvim_create_user_command('ShooterQueueNext', function()
    local tmux = require('shooter.tmux')
    tmux.send_queued_shot()
  end, { desc = 'Send next queued shot' })

  -- Context management commands
  vim.api.nvim_create_user_command('ShooterContextInject', function()
    local context = require('shooter.core.context')
    context.inject_context()
  end, { desc = 'Inject context into current shot' })

  vim.api.nvim_create_user_command('ShooterContextEdit', function(opts)
    local context = require('shooter.core.context')
    local scope = opts.args ~= '' and opts.args or 'project'
    if scope == 'general' then
      context.edit_general_context()
    else
      context.edit_project_context()
    end
  end, { nargs = '?', complete = function() return { 'general', 'project' } end, desc = 'Edit context file' })
end

-- Setup default keymaps
function M._setup_keymaps()
  local config = require('shooter.config')
  local prefix = config.get('keymaps.prefix')
  local move_prefix = config.get('keymaps.move_prefix')
  local copy_prefix = config.get('keymaps.copy_prefix')

  -- Shot sending keymaps (space + 1-4)
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. tostring(i), function()
      local tmux = require('shooter.tmux')
      tmux.send_current_shot(i)
    end, { desc = 'Send shot to pane ' .. i })
  end

  -- Shot navigation
  vim.keymap.set('n', prefix .. 'j', function()
    local movement = require('shooter.core.movement')
    movement.jump_to_next_shot()
  end, { desc = 'Jump to next shot' })

  vim.keymap.set('n', prefix .. 'k', function()
    local movement = require('shooter.core.movement')
    movement.jump_to_prev_shot()
  end, { desc = 'Jump to previous shot' })

  -- File pickers
  vim.keymap.set('n', prefix .. 'f', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files()
    if picker then picker:find() end
  end, { desc = 'Find shooter files' })

  vim.keymap.set('n', prefix .. 's', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then picker:find() end
  end, { desc = 'Find open shots' })

  -- Queue management
  vim.keymap.set('n', prefix .. 'q', function()
    local queue_picker = require('shooter.queue.picker')
    queue_picker.show_queue()
  end, { desc = 'View shot queue' })

  vim.keymap.set('n', prefix .. 'qa', function()
    local queue = require('shooter.queue')
    queue.add_to_queue()
  end, { desc = 'Add shot to queue' })

  vim.keymap.set('n', prefix .. 'qn', function()
    local tmux = require('shooter.tmux')
    tmux.send_queued_shot()
  end, { desc = 'Send next queued shot' })

  -- Context injection
  vim.keymap.set('n', prefix .. 'c', function()
    local context = require('shooter.core.context')
    context.inject_context()
  end, { desc = 'Inject context' })
end

-- Get current configuration
function M.get_config()
  return M._config
end

-- Check if plugin is initialized
function M.is_initialized()
  return M._initialized
end

return M

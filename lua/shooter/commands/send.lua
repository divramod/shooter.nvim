-- Send and queue command registration for shooter.nvim

local M = {}

function M.setup()
  -- Send commands (1-9)
  for i = 1, 9 do
    vim.api.nvim_create_user_command('ShooterSend' .. i, function()
      local tmux = require('shooter.tmux')
      tmux.send_current_shot(i)
    end, { desc = 'Send current shot to pane ' .. i })

    vim.api.nvim_create_user_command('ShooterSendAll' .. i, function()
      local tmux = require('shooter.tmux')
      tmux.send_all_shots(i)
    end, { desc = 'Send all open shots to pane ' .. i })

    vim.api.nvim_create_user_command('ShooterSendVisual' .. i, function(opts)
      local tmux = require('shooter.tmux')
      local start_line = opts.line1
      local end_line = opts.line2
      tmux.send_visual_selection(i, start_line, end_line)
    end, { range = true, desc = 'Send visual selection to pane ' .. i })

    vim.api.nvim_create_user_command('ShooterResend' .. i, function()
      local tmux = require('shooter.tmux')
      tmux.resend_latest_shot(i)
    end, { desc = 'Resend latest shot to pane ' .. i })
  end

  -- Queue commands (1-4)
  for i = 1, 4 do
    vim.api.nvim_create_user_command('ShooterQueueAdd' .. i, function()
      local queue = require('shooter.queue')
      queue.add_to_queue(nil, i)
    end, { desc = 'Add current shot to queue for pane ' .. i })
  end

  vim.api.nvim_create_user_command('ShooterQueueView', function()
    local queue_picker = require('shooter.queue.picker')
    queue_picker.show_queue()
  end, { desc = 'View shot queue' })

  vim.api.nvim_create_user_command('ShooterQueueClear', function()
    local queue = require('shooter.queue')
    queue.clear_queue()
  end, { desc = 'Clear shot queue' })
end

return M

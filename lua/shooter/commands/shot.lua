-- Shot namespace commands (s prefix in keymaps).

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd
local require_shotfile = util.require_shotfile

local M = {}

function M.setup()
  local shot_actions = require('shooter.core.shot_actions')
  local tmux = require('shooter.tmux')

  create_cmd('HalShooterShotNew', require_shotfile(shot_actions.create_new_shot),
    { desc = 'Create new shot' })

  create_cmd('HalShooterShotNewWhisper', require_shotfile(shot_actions.create_new_shot_with_whisper),
    { desc = 'New shot + whisper' })

  create_cmd('HalShooterShotDelete', require_shotfile(shot_actions.delete_last_shot),
    { desc = 'Delete last shot' })

  create_cmd('HalShooterShotToggle', require_shotfile(function()
    require('shooter.core.shot_actions').toggle_shot_done()
  end), { desc = 'Toggle shot done' })

  create_cmd('HalShooterShotDeleteCursor', require_shotfile(function()
    require('shooter.core.shot_delete').delete_shot_under_cursor()
  end), { desc = 'Delete shot under cursor' })

  create_cmd('HalShooterShotMove', require_shotfile(function()
    require('shooter.core.shot_move').move_shot()
  end), { desc = 'Move shot to another file' })

  create_cmd('HalShooterShotYank', require_shotfile(shot_actions.yank_shot),
    { desc = 'Yank shot to clipboard' })

  create_cmd('HalShooterShotViewResponse', require_shotfile(function()
    require('shooter.tools.response_viewer').view_response()
  end), { desc = 'View response for shot' })

  create_cmd('HalShooterShotExtractBlock', require_shotfile(shot_actions.extract_subtask),
    { desc = 'Extract ### subtask block to new shot' })

  create_cmd('HalShooterShotExtractLine', require_shotfile(shot_actions.extract_line),
    { desc = 'Extract current line to new shot' })

  create_cmd('HalShooterShotMunition', require_shotfile(function()
    require('shooter.inbox.picker').show_file_picker()
  end), { desc = 'Import tasks from inbox' })

  create_cmd('HalShooterShotPicker', require_shotfile(function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then picker:find() end
  end), { desc = 'Open shots picker' })

  -- Navigation
  create_cmd('HalShooterShotNavNext', require_shotfile(shot_actions.goto_next_open_shot),
    { desc = 'Next open shot' })
  create_cmd('HalShooterShotNavPrev', require_shotfile(shot_actions.goto_prev_open_shot),
    { desc = 'Previous open shot' })
  create_cmd('HalShooterShotNavNextSent', require_shotfile(shot_actions.goto_next_sent_shot),
    { desc = 'Next sent shot' })
  create_cmd('HalShooterShotNavPrevSent', require_shotfile(shot_actions.goto_prev_sent_shot),
    { desc = 'Previous sent shot' })
  create_cmd('HalShooterShotNavLatest', require_shotfile(shot_actions.goto_latest_sent_shot),
    { desc = 'Latest sent shot' })
  create_cmd('HalShooterShotNavUndo', require_shotfile(shot_actions.undo_latest_sent_shot),
    { desc = 'Undo latest sent' })

  -- Send
  create_cmd('HalShooterShotSend', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_current_shot(pane)
  end), { nargs = '?', desc = 'Send shot to pane [1-9]' })

  create_cmd('HalShooterShotSendAll', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_all_shots(pane)
  end), { nargs = '?', desc = 'Send all shots to pane [1-9]' })

  create_cmd('HalShooterShotSendVisual', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_visual_selection(pane, opts.line1, opts.line2)
  end), { range = true, nargs = '?', desc = 'Send selection to pane [1-9]' })

  create_cmd('HalShooterShotResend', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.resend_latest_shot(pane)
  end), { nargs = '?', desc = 'Resend to pane [1-9]' })

  -- Queue (1-9)
  local queue = require('shooter.queue')
  for i = 1, 9 do
    create_cmd('HalShooterShotQueue' .. i, require_shotfile(function()
      queue.add_to_queue(nil, i)
    end), { desc = 'Queue for pane ' .. i })
  end

  create_cmd('HalShooterShotQueueView', require_shotfile(function()
    require('shooter.queue.picker').show_queue()
  end), { desc = 'View queue' })

  create_cmd('HalShooterShotQueueClear', require_shotfile(function()
    queue.clear_queue()
  end), { desc = 'Clear queue' })

  create_cmd('HalShooterFileStats', require_shotfile(shot_actions.file_stats),
    { desc = 'Shotfile stats (total/open/closed)' })

  create_cmd('HalShooterFileToggleFirstShotOfDayColoring', require_shotfile(function()
    require('shooter.syntax').toggle_day_marker()
  end), { desc = 'Toggle first-shot-of-day coloring' })

  create_cmd('HalShooterShotCreateFromClaude', shot_actions.create_shot_from_claude,
    { desc = 'Cut Claude text, create shot in right pane' })

  create_cmd('HalShooterShotsRenumber', require_shotfile(function()
    local renumber = require('shooter.core.renumber')
    local count = renumber.renumber_shots()
    if count > 0 then
    end
  end), { desc = 'Renumber shots sequentially' })
end

return M

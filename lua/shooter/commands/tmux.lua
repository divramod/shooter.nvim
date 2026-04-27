-- Tmux namespace commands (t prefix in keymaps).

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd

local M = {}

function M.setup()
  local wrapper = require('shooter.tmux.wrapper')

  create_cmd('HalShooterTmuxZoom', wrapper.zoom_toggle, { desc = 'Tmux: zoom toggle' })
  create_cmd('HalShooterTmuxEdit', wrapper.edit_in_vim, { desc = 'Tmux: edit in vim' })
  create_cmd('HalShooterTmuxGit', wrapper.git_status_toggle, { desc = 'Tmux: git status' })
  create_cmd('HalShooterTmuxLight', wrapper.lightswitch, { desc = 'Tmux: light/dark' })
  create_cmd('HalShooterTmuxKillOthers', wrapper.kill_other_panes, { desc = 'Tmux: kill others' })
  create_cmd('HalShooterTmuxReload', wrapper.reload_session, { desc = 'Tmux: reload' })
  create_cmd('HalShooterTmuxDelete', wrapper.delete_session, { desc = 'Tmux: delete session' })
  create_cmd('HalShooterTmuxSmug', wrapper.smug_load, { desc = 'Tmux: smug load' })
  create_cmd('HalShooterTmuxYank', wrapper.yank_to_vim, { desc = 'Tmux: yank to vim' })
  create_cmd('HalShooterTmuxChoose', wrapper.choose_session, { desc = 'Tmux: choose session' })
  create_cmd('HalShooterTmuxSwitch', wrapper.switch_last, { desc = 'Tmux: switch last' })

  create_cmd('HalShooterTmuxWatch', function()
    require('shooter.tmux.watch').open_watch_pane()
  end, { desc = 'Tmux: watch pane' })

  -- Pane toggle (0-9)
  for i = 0, 9 do
    create_cmd('HalShooterTmuxPaneToggle' .. i, function()
      require('shooter.tmux.panes').toggle(i)
    end, { desc = 'Toggle pane ' .. i })
  end

  create_cmd('HalShooterTmuxTogglePanes', function()
    require('shooter.tmux.toggle_panes').setup_tmux_keybinding()
    require('shooter.telescope.toggle_panes_picker').show_picker()
  end, { desc = 'Tmux: toggle configured panes' })

  create_cmd('HalShooterTmuxSetupHideKey', function()
    require('shooter.tmux.toggle_panes').setup_tmux_keybinding()
  end, { desc = 'Tmux: set up prefix+H keybinding for hiding panes' })
end

return M

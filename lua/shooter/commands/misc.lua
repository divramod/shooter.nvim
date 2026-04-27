-- Misc namespace commands — Analytics + Help + GitWorktree + Domain + Session.
-- Each block registers its area's commands in the order originally called.

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd
local require_shotfile = util.require_shotfile

local M = {}

local function setup_analytics_commands()
  create_cmd('HalShooterAnalyticsProject', function()
    require('shooter.analytics').show_project()
  end, { desc = 'Project analytics' })

  create_cmd('HalShooterAnalyticsGlobal', function()
    require('shooter.analytics').show_global()
  end, { desc = 'Global analytics' })
end

local function setup_help_commands()
  create_cmd('HalShooterHelp', function()
    require('shooter.help').show()
  end, { desc = 'Show help' })

  create_cmd('HalShooterHealth', function()
    vim.cmd('checkhealth shooter')
  end, { desc = 'Health check' })

  create_cmd('HalShooterHelpDashboard', function()
    require('shooter.dashboard').open()
  end, { desc = 'Open dashboard' })

  create_cmd('HalShooterCheatsheet', function()
    require('shooter.cheatsheet').show()
  end, { desc = 'Show cheatsheet' })
end

local function setup_git_worktree_commands()
  local git_wt = require('shooter.tools.git_worktree')

  create_cmd('HalShooteroterGitWorktreeSwitchTo', function(opts)
    local num = opts.args ~= '' and tonumber(opts.args) or nil
    git_wt.switch_to(num)
  end, { nargs = '?', desc = 'Switch to git worktree by number or pick' })

  create_cmd('HalShooteroterGitWorktreeToMain', function()
    git_wt.to_main()
  end, { desc = 'Switch back to main git worktree' })

  create_cmd('HalShooteroterGitWorktreeLast', function()
    git_wt.to_last()
  end, { desc = 'Switch to last git worktree' })
end

local function setup_domain_commands()
  local domain = require('shooter.core.domain')

  create_cmd('HalShooterDomainNew', function(opts)
    if opts.args ~= '' then
      domain.create_domain(opts.args)
    else
      vim.ui.input({ prompt = 'Domain name: ' }, function(name)
        if name and name ~= '' then domain.create_domain(name) end
      end)
    end
  end, { nargs = '?', desc = 'Create new domain' })

  create_cmd('HalShooterDomainMoveShotfileToDomain', require_shotfile(function()
    domain.pick_and_move()
  end), { desc = 'Move shotfile to domain' })

  create_cmd('HalShooterDomainRename', function()
    domain.rename()
  end, { desc = 'Rename domain' })
end

local function setup_session_commands()
  for i = 1, 9 do
    create_cmd('HalShooterSessionClear' .. i, function()
      local detect = require('shooter.tmux.detect')
      local utils = require('shooter.utils')

      local pane_id, err = detect.find_ai_pane(i)
      if not pane_id then
        utils.echo(err or 'No AI pane found')
        return
      end

      -- Safety: never send to nvim's own pane
      local nvim_pane = vim.trim(vim.fn.system({"tmux", "display-message", "-p", "#{pane_id}"}))
      if pane_id == nvim_pane then
        utils.echo('Error: AI pane ID matches nvim pane, aborting')
        return
      end

      vim.fn.system(string.format(
        "tmux send-keys -t %s C-c && sleep 0.05 && tmux send-keys -t %s C-u && sleep 0.1 && tmux send-keys -t %s /clear Enter",
        pane_id, pane_id, pane_id
      ))
      utils.echo('Cleared session in pane ' .. i)
    end, { desc = 'Clear AI session ' .. i })
  end
end

-- Per init.lua's M.setup() ordering: domain + session run before tool/cfg;
-- analytics/help/git_worktree run after utility. The init.lua composer calls
-- M.setup_domain / M.setup_session / M.setup_analytics / M.setup_help /
-- M.setup_git_worktree directly so order is preserved.
M.setup_analytics = setup_analytics_commands
M.setup_help = setup_help_commands
M.setup_git_worktree = setup_git_worktree_commands
M.setup_domain = setup_domain_commands
M.setup_session = setup_session_commands

return M

-- shooter.commands public surface — calls each sub-area's setup() in the
-- original order so :HalShooter* command registration is identical to the
-- pre-split commands.lua.

local M = {}

function M.setup()
  require('shooter.commands.shotfile').setup()
  require('shooter.commands.shot').setup()

  local utility = require('shooter.commands.utility')
  utility.setup_bullet()

  require('shooter.commands.tmux').setup()
  require('shooter.commands.plan').setup()

  local misc = require('shooter.commands.misc')
  misc.setup_domain()
  misc.setup_session()

  require('shooter.commands.tool').setup()

  require('shooter.commands.cfg').setup()

  misc.setup_analytics()
  misc.setup_help()

  utility.setup_nav()

  misc.setup_git_worktree()

  utility.setup_utility()
end

return M

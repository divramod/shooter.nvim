-- User-command registration smoke test.
-- Asserts a representative subset of `:HalShooter*` commands are
-- registered after shooter.commands.setup() runs. Used as the regression
-- guard for Phase 002 T006 (commands.lua split or exception).

describe('shooter.commands user-command registration', function()
  -- Run setup once for the whole suite.
  before_each(function()
    require('shooter.commands').setup()
  end)

  local function registered(name)
    local cmds = vim.api.nvim_get_commands({})
    return cmds[name] ~= nil
  end

  -- A representative subset; if any of these is missing post-setup,
  -- something in the registration chain broke. Not exhaustive — the goal
  -- is a regression guard, not a full enumeration.
  local expected = {
    -- shotfile area
    'HalShooterCheatsheet',
    'HalShooterFixAll',
    'HalShooterGitPush',
    -- shot area
    'HalShooterFileStats',
    -- plan area
    'HalShooterMetaplanOpen',
    'HalShooterMetaplanFix',
    'HalShooterMetaplanMarkDone',
    'HalShooterMetaplanOpenSpec',
    'HalShooterPlanNew',
    'HalShooterPlanDelete',
    -- cfg area
    'HalShooterCfgFix',
    'HalShooterCfgReload',
    'HalShooterCfgEditGlobal',
    'HalShooterCfgEditLocal',
    -- analytics / help / domain
    'HalShooterAnalyticsGlobal',
    'HalShooterHelp',
    'HalShooterHealth',
    'HalShooterDomainNew',
    -- nav
    'HalShooterNavLastEditedFile',
    'HalShooterNavLastEditedFiles',
    'HalShooterOpenLinkPicker',
    -- inbox
    'HalShooterInbox',
  }

  for _, name in ipairs(expected) do
    it('registers :' .. name, function()
      assert.is_true(registered(name))
    end)
  end
end)

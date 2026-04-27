-- Phase 002 T006 registration smoke: every :HalShooter* / Hal<Domain>Config* /
-- HalConfigPicker user command resolves on a fresh Neovim post-setup().
-- Catches drift from the commands.lua → commands/ split and any future
-- regressions where a sub-area's setup() is dropped from the M.setup() chain.

describe('shooter.commands registration', function()
  before_each(function()
    package.loaded['shooter.commands'] = nil
    require('shooter.commands').setup()
  end)

  -- Static commands (no numeric/domain suffix). Drift catcher: if a sub-area's
  -- setup() disappears from commands/init.lua's M.setup(), the names below
  -- vanish and this spec fails first.
  local STATIC_COMMANDS = {
    -- shotfile
    'HalShooterShotfileNew', 'HalShooterShotfileNewInRepo',
    'HalShooterShotfilePicker', 'HalShooterShotfilePickerAll',
    'HalShooterShotfileLast', 'HalShooterShotfileRename',
    'HalShooterShotfileDelete', 'HalShooterShotfileOpenPrompts',
    'HalShooterOpenPlans', 'HalShooterOpenShoConfig',
    'HalShooterShotfileMoveArchive', 'HalShooterShotfileMoveBacklog',
    'HalShooterShotfileMoveDone', 'HalShooterShotfileMovePrompts',
    'HalShooterShotfileMoveReqs', 'HalShooterShotfileMoveTest',
    'HalShooterShotfileMoveWait', 'HalShooterShotfileMoveGitRoot',
    'HalShooterShotfileMovePicker', 'HalShooterFixAll',
    'HalShooterShotfileFix',
    -- shot
    'HalShooterShotNew', 'HalShooterShotNewWhisper',
    'HalShooterShotDelete', 'HalShooterShotToggle',
    'HalShooterShotDeleteCursor', 'HalShooterShotMove',
    'HalShooterShotYank', 'HalShooterShotViewResponse',
    'HalShooterShotExtractBlock', 'HalShooterShotExtractLine',
    'HalShooterShotMunition', 'HalShooterShotPicker',
    'HalShooterShotNavNext', 'HalShooterShotNavPrev',
    'HalShooterShotNavNextSent', 'HalShooterShotNavPrevSent',
    'HalShooterShotNavLatest', 'HalShooterShotNavUndo',
    'HalShooterShotSend', 'HalShooterShotSendAll',
    'HalShooterShotSendVisual', 'HalShooterShotResend',
    'HalShooterShotQueueView', 'HalShooterShotQueueClear',
    'HalShooterFileStats', 'HalShooterFileToggleFirstShotOfDayColoring',
    'HalShooterShotCreateFromClaude', 'HalShooterShotsRenumber',
    -- bullet (utility.setup_bullet)
    'HalShooterBulletPickerCurrentFile', 'HalShooterBulletPickerCurrentRepo',
    'HalShooterBulletPickerAllRepos',
    -- tmux
    'HalShooterTmuxZoom', 'HalShooterTmuxEdit', 'HalShooterTmuxGit',
    'HalShooterTmuxLight', 'HalShooterTmuxKillOthers', 'HalShooterTmuxReload',
    'HalShooterTmuxDelete', 'HalShooterTmuxSmug', 'HalShooterTmuxYank',
    'HalShooterTmuxChoose', 'HalShooterTmuxSwitch',
    'HalShooterTmuxWatch', 'HalShooterTmuxTogglePanes',
    'HalShooterTmuxSetupHideKey',
    -- plan
    'HalShooterPlanPickerPlan', 'HalShooterPlanPickerContext',
    'HalShooterPlanPickerSpec', 'HalShooterPlanPickerIdea',
    'HalShooterPlanOpenIdea', 'HalShooterPlanNew',
    'HalShooterPlanRename', 'HalShooterPlanDelete',
    -- domain
    'HalShooterDomainNew', 'HalShooterDomainMoveShotfileToDomain',
    'HalShooterDomainRename',
    -- tool
    'HalShooterToolToken', 'HalShooterToolObsidian', 'HalShooterToolImages',
    'HalShooterToolPrd', 'HalShooterToolGreenkeep', 'HalShooterToolSoundTest',
    'HalShooterToolClipboardPaste', 'HalShooterToolClipboardCheck',
    'HalShooterToolClipboardImages',
    -- cfg
    'HalShooterCfgGlobal', 'HalShooterCfgProject', 'HalShooterCfgPlugin',
    'HalShooterCfgShot', 'HalShooterCfgReload', 'HalShooterCfgEditGlobal',
    'HalShooterCfgEditLocal', 'HalShooterCfgFix', 'HalShooterCfgShotfile',
    -- hal config picker
    'HalConfigPicker',
    -- analytics + help
    'HalShooterAnalyticsProject', 'HalShooterAnalyticsGlobal',
    'HalShooterHelp', 'HalShooterHealth',
    'HalShooterHelpDashboard', 'HalShooterCheatsheet',
    -- nav
    'HalShooterNavLastEditedFile', 'HalShooterNavLastEditedFiles',
    -- git worktree
    'HalShooteroterGitWorktreeSwitchTo', 'HalShooteroterGitWorktreeToMain',
    'HalShooteroterGitWorktreeLast',
    -- utility
    'HalShooterClearFilter', 'HalShooterInbox',
    'HalShooterMetaplanOpen', 'HalShooterMetaplanFix',
    'HalShooterMetaplanOpenPlan', 'HalShooterMetaplanOpenContext',
    'HalShooterMetaplanOpenSpec', 'HalShooterMetaplanOpenMasterplan',
    'HalShooterMetaplanMarkDone', 'HalShooterGitPush',
    'HalShooterShotfileMergeInto', 'HalShooterOpenLinkPicker',
    'HalShooterOpenLinkPickerTmux', 'HalShooterGitWorktreeOpenOil',
  }

  -- Hal-domain config commands: 14 domains × {Show, Edit} = 28 commands.
  local HAL_CONFIG_DOMAINS = {
    'Agent', 'Api', 'Compose', 'Daemon', 'Env', 'Mcp', 'Port', 'Repo',
    'Server', 'Shooter', 'Smug', 'Sync', 'Template', 'Youtube',
  }

  local function exists(name)
    return vim.fn.exists(':' .. name) == 2
  end

  it('registers every static :HalShooter* / HalConfigPicker command', function()
    for _, name in ipairs(STATIC_COMMANDS) do
      assert.is_true(exists(name), 'missing command: ' .. name)
    end
  end)

  it('registers Hal<Domain>Config{Show,Edit} for all 14 hal domains', function()
    for _, dom in ipairs(HAL_CONFIG_DOMAINS) do
      assert.is_true(exists('Hal' .. dom .. 'ConfigShow'),
        'missing: Hal' .. dom .. 'ConfigShow')
      assert.is_true(exists('Hal' .. dom .. 'ConfigEdit'),
        'missing: Hal' .. dom .. 'ConfigEdit')
    end
  end)

  it('registers HalShooterShotQueue1..9', function()
    for i = 1, 9 do
      assert.is_true(exists('HalShooterShotQueue' .. i),
        'missing: HalShooterShotQueue' .. i)
    end
  end)

  it('registers HalShooterTmuxPaneToggle0..9', function()
    for i = 0, 9 do
      assert.is_true(exists('HalShooterTmuxPaneToggle' .. i),
        'missing: HalShooterTmuxPaneToggle' .. i)
    end
  end)

  it('registers HalShooterSessionClear1..9', function()
    for i = 1, 9 do
      assert.is_true(exists('HalShooterSessionClear' .. i),
        'missing: HalShooterSessionClear' .. i)
    end
  end)

  it('exposes an idempotent M.setup()', function()
    require('shooter.commands').setup()
    assert.is_true(exists('HalShooterShotNew'))
  end)
end)

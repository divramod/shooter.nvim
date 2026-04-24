-- Default keybindings for shooter.nvim
-- Organized by namespace with subprefixes

local M = {}

-- Setup default keymaps
function M.setup()
  local config = require('shooter.config')

  if not config.get('keymaps.enabled') then
    return
  end

  local prefix = config.get('keymaps.prefix')
  local opts = { noremap = true, silent = true }

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, prefix .. lhs, rhs, vim.tbl_extend('force', opts, { desc = desc }))
  end

  -- ============================================================
  -- CORE SHORTCUTS (root level for quick access)
  -- ============================================================
  map('n', 'N', ':HalShooterShotfileNew<cr>', 'New shotfile')
  map('n', 'n', ':HalShooterShotNew<cr>', 'New shot')
  map('n', 'o', ':HalShooterShotPicker<cr>', 'Open shots picker')
  map('n', 'v', ':HalShooterShotfilePicker<cr>', 'Shotfile picker')
  map('n', 'l', ':HalShooterShotfileLast<cr>', 'Last shotfile')
  map('n', 'L', ':HalShooterRepoOpenLastEditedFile<cr>', 'Last edited file in repo')
  map('n', 'i', ':HalShooterInbox<cr>', 'Open INBOX.md')
  map('n', '.', ':HalShooterShotToggle<cr>', 'Toggle shot done')
  map('n', 'y', ':HalShooterShotYank<cr>', 'Yank shot')
  map('n', 'z', ':HalShooterNavLastEditedFiles 10<cr>', 'Last 10 edited files')
  map('n', '?', ':HalShooterCheatsheet<cr>', 'Cheatsheet')

  -- Shot navigation - root level for speed
  map('n', ']', ':HalShooterShotNavNext<cr>', 'Next open shot')
  map('n', '[', ':HalShooterShotNavPrev<cr>', 'Prev open shot')
  map('n', '}', ':HalShooterShotNavNextSent<cr>', 'Next sent shot')
  map('n', '{', ':HalShooterShotNavPrevSent<cr>', 'Prev sent shot')

  -- Send to pane (1-9) - root level for speed
  for i = 1, 9 do
    map('n', tostring(i), ':HalShooterShotSend ' .. i .. '<cr>', 'Send to pane ' .. i)
    map('v', tostring(i), ':HalShooterShotSendVisual ' .. i .. '<cr>', 'Send selection to pane ' .. i)
  end

  -- ============================================================
  -- SHOTFILE NAMESPACE (f prefix)
  -- ============================================================
  map('n', 'fn', ':HalShooterShotfileNew<cr>', 'New shotfile')
  map('n', 'fN', ':HalShooterShotfileNewInRepo<cr>', 'New in other repo')
  map('n', 'fp', ':HalShooterShotfilePicker<cr>', 'Shotfile picker')
  map('n', 'fP', ':HalShooterShotfilePickerAll<cr>', 'All repos picker')
  map('n', 'fl', ':HalShooterShotfileLast<cr>', 'Last edited file')
  map('n', 'fr', ':HalShooterShotfileRename<cr>', 'Rename current')
  map('n', 'fd', ':HalShooterShotfileDelete<cr>', 'Delete current')
  map('n', 'fo', ':HalShooterShotfileOpenPrompts<cr>', 'Oil prompts folder')
  map('n', 'fs', ':HalShooterFileStats<cr>', 'File stats')
  map('n', 'ff', ':HalShooterShotfileFix<cr>', 'Fix current shotfile (title, empties, renumber, commit)')
  map('n', 'fa', ':HalShooterFixAll<cr>', 'Fix all shotfiles in repo')
  map('n', 'fM', ':HalShooterShotfileMergeInto<cr>', 'Merge current shotfile into another')
  map('n', 'x', ':HalShooterOpenLinkPicker<cr>', 'Open link picker (current file)')
  map('n', 'X', ':HalShooterOpenLinkPickerTmux<cr>', 'Open link picker (tmux window)')
  map('n', 'fcf', ':HalShooterFileToggleFirstShotOfDayColoring<cr>', 'Toggle day markers')

  -- Shotfile move commands (fm prefix)
  map('n', 'fma', ':HalShooterShotfileMoveArchive<cr>', 'Move to archive')
  map('n', 'fmb', ':HalShooterShotfileMoveBacklog<cr>', 'Move to backlog')
  map('n', 'fmd', ':HalShooterShotfileMoveDone<cr>', 'Move to done')
  map('n', 'fmp', ':HalShooterShotfileMovePrompts<cr>', 'Move to prompts')
  map('n', 'fmr', ':HalShooterShotfileMoveReqs<cr>', 'Move to reqs')
  map('n', 'fmt', ':HalShooterShotfileMoveTest<cr>', 'Move to test')
  map('n', 'fmw', ':HalShooterShotfileMoveWait<cr>', 'Move to wait')
  map('n', 'fmg', ':HalShooterShotfileMoveGitRoot<cr>', 'Move to git root')
  map('n', 'fmm', ':HalShooterShotfileMovePicker<cr>', 'Fuzzy folder picker')

  -- ============================================================
  -- SHOT NAMESPACE (s prefix)
  -- ============================================================
  map('n', 'ss', ':HalShooterShotNew<cr>', 'New shot')
  map('n', 'sS', ':HalShooterShotNewWhisper<cr>', 'New shot + whisper')
  map('n', 'sd', ':HalShooterShotDelete<cr>', 'Delete last shot')
  map('n', 'sD', ':HalShooterShotDeleteCursor<cr>', 'Delete shot at cursor')
  map('n', 's.', ':HalShooterShotToggle<cr>', 'Toggle done')
  map('n', 'sm', ':HalShooterShotMove<cr>', 'Move to another file')
  map('n', 'sM', ':HalShooterShotMunition<cr>', 'Import from inbox')
  map('n', 'sy', ':HalShooterShotYank<cr>', 'Yank shot to clipboard')
  map('n', 'se', ':HalShooterShotExtractBlock<cr>', 'Extract block to new shot')
  map('n', 'sE', ':HalShooterShotExtractLine<cr>', 'Extract line to new shot')
  map('n', 'sp', ':HalShooterShotPicker<cr>', 'Open shots picker')
  map('n', 'sr', ':HalShooterShotsRenumber<cr>', 'Renumber shots')
  map('n', 'sC', ':HalShooterShotCreateFromClaude<cr>', 'Create shot from Claude')

  -- Shot navigation
  map('n', 's]', ':HalShooterShotNavNext<cr>', 'Next open shot')
  map('n', 's[', ':HalShooterShotNavPrev<cr>', 'Prev open shot')
  map('n', 's}', ':HalShooterShotNavNextSent<cr>', 'Next sent shot')
  map('n', 's{', ':HalShooterShotNavPrevSent<cr>', 'Prev sent shot')
  map('n', 'sL', ':HalShooterShotNavLatest<cr>', 'Latest sent')
  map('n', 'su', ':HalShooterShotNavUndo<cr>', 'Undo sent marking')
  map('n', 'sv', ':HalShooterShotViewResponse<cr>', 'View shot response')

  -- Shot send (also at root, but available with s prefix too)
  for i = 1, 9 do
    map('n', 's' .. i, ':HalShooterShotSend ' .. i .. '<cr>', 'Send to pane ' .. i)
    map('n', 'sR' .. i, ':HalShooterShotResend ' .. i .. '<cr>', 'Resend to pane ' .. i)
  end

  -- Shot queue
  for i = 1, 9 do
    map('n', 'sq' .. i, ':HalShooterShotQueue' .. i .. '<cr>', 'Queue for pane ' .. i)
  end
  map('n', 'sqQ', ':HalShooterShotQueueView<cr>', 'View queue')

  -- ============================================================
  -- SESSION NAMESPACE (sc prefix)
  -- ============================================================
  for i = 1, 9 do
    map('n', 'sc' .. i, ':HalShooterSessionClear' .. i .. '<cr>', 'Clear session ' .. i)
  end

  -- ============================================================
  -- BULLET NAMESPACE (b prefix)
  -- ============================================================
  map('n', 'bf', ':HalShooterBulletPickerCurrentFile<cr>', 'Bullet picker (current file)')
  map('n', 'br', ':HalShooterBulletPickerCurrentRepo<cr>', 'Bullet picker (current repo)')
  map('n', 'ba', ':HalShooterBulletPickerAllRepos<cr>', 'Bullet picker (all repos)')

  -- ============================================================
  -- DOMAIN NAMESPACE (d prefix)
  -- ============================================================
  map('n', 'dn', ':HalShooterDomainNew<cr>', 'New domain')
  map('n', 'dmf', ':HalShooterDomainMoveShotfileToDomain<cr>', 'Move shotfile to domain')
  map('n', 'dr', ':HalShooterDomainRename<cr>', 'Rename domain')

  -- ============================================================
  -- TMUX NAMESPACE (t prefix)
  -- ============================================================
  map('n', 'tt', ':HalShooterTmuxTogglePanes<cr>', 'Toggle configured panes')
  map('n', 'tz', ':HalShooterTmuxZoom<cr>', 'Zoom toggle')
  map('n', 'te', ':HalShooterTmuxEdit<cr>', 'Edit pane in vim')
  map('n', 'tg', ':HalShooterTmuxGit<cr>', 'Git status toggle')
  map('n', 'ti', ':HalShooterTmuxLight<cr>', 'Light/dark toggle')
  map('n', 'to', ':HalShooterTmuxKillOthers<cr>', 'Kill other panes')
  map('n', 'tr', ':HalShooterTmuxReload<cr>', 'Reload session')
  map('n', 'td', ':HalShooterTmuxDelete<cr>', 'Delete session')
  map('n', 'ts', ':HalShooterTmuxSmug<cr>', 'Smug load')
  map('n', 'ty', ':HalShooterTmuxYank<cr>', 'Yank pane to vim')
  map('n', 'tc', ':HalShooterTmuxChoose<cr>', 'Choose session')
  map('n', 'tp', ':HalShooterTmuxSwitch<cr>', 'Switch to last')
  map('n', 'tw', ':HalShooterTmuxWatch<cr>', 'Watch pane')

  -- Pane toggle (t0-t9)
  for i = 0, 9 do
    map('n', 't' .. i, ':HalShooterTmuxPaneToggle' .. i .. '<cr>', 'Toggle pane ' .. i)
  end

  -- ============================================================
  -- PLAN NAMESPACE (p prefix)
  -- ============================================================
  map('n', 'pp', ':HalShooterPlanPickerPlan<cr>',    'Pick docs/plans/**/plan.md')
  map('n', 'pc', ':HalShooterPlanPickerContext<cr>', 'Pick docs/plans/**/context.md')
  map('n', 'ps', ':HalShooterPlanPickerSpec<cr>',    'Pick docs/plans/**/spec.md')
  map('n', 'pe', ':HalShooterPlanEdit<cr>',          'Edit plan shotfile (create/rename/open)')

  -- ============================================================
  -- TOOLS NAMESPACE (l prefix)
  -- ============================================================
  map('n', 'lt', ':HalShooterToolToken<cr>', 'Token counter')
  map('n', 'lo', ':HalShooterToolObsidian<cr>', 'Open in Obsidian')
  map('n', 'li', ':HalShooterToolImages<cr>', 'Insert images')
  map('n', 'lw', ':HalShooterTmuxWatch<cr>', 'Watch pane')
  map('n', 'lp', ':HalShooterToolPrd<cr>', 'PRD list')
  map('n', 'lc', ':HalShooterToolClipboardPaste<cr>', 'Paste clipboard image')
  map('n', 'lI', ':HalShooterToolClipboardImages<cr>', 'Open images folder')

  -- ============================================================
  -- CFG NAMESPACE (c prefix)
  -- ============================================================
  map('n', 'cg', ':HalShooterCfgGlobal<cr>', 'Edit global context')
  map('n', 'cp', ':HalShooterCfgProject<cr>', 'Edit project context')
  map('n', 'ce', ':HalShooterCfgPlugin<cr>', 'Edit shooter.lua plugin')
  map('n', 'cs', ':HalShooterCfgShot<cr>', 'Shot picker config')
  map('n', 'cf', ':HalShooterCfgShotfile<cr>', 'Shotfile picker config')
  map('n', 'cR', ':HalShooterCfgReload<cr>', 'Reload YAML config')
  map('n', 'cG', ':HalShooterCfgEditGlobal<cr>', 'Edit global YAML config')
  map('n', 'cL', ':HalShooterCfgEditLocal<cr>', 'Edit local YAML config')
  map('n', 'cF', ':HalShooterCfgFix<cr>', 'Fix YAML config')
  map('n', 'C', ':HalConfigPicker<cr>', 'Hal config picker')

  -- ============================================================
  -- ANALYTICS NAMESPACE (A prefix)
  -- ============================================================
  map('n', 'Ap', ':HalShooterAnalyticsProject<cr>', 'Project analytics')
  map('n', 'Aa', ':HalShooterAnalyticsGlobal<cr>', 'Global analytics')

  -- ============================================================
  -- HELP NAMESPACE (h prefix)
  -- ============================================================
  map('n', 'hh', ':HalShooterHelp<cr>', 'Show help')
  map('n', 'hH', ':HalShooterHealth<cr>', 'Health check')
  map('n', 'hd', ':HalShooterHelpDashboard<cr>', 'Dashboard')

  -- ============================================================
  -- QUICK FOLDER ACCESS (, prefix)
  -- ============================================================
  map('n', ',p', ':HalShooterShotfileOpenPrompts<cr>', 'Open prompts folder')
  map('n', ',l', ':HalShooterOpenPlans<cr>', 'Open plans folder')
  map('n', ',s', ':HalShooterOpenShoConfig<cr>', 'Open .shooter/config/nvim folder')

  -- ============================================================
  -- NAV NAMESPACE (z prefix) - Navigation commands
  -- ============================================================
  map('n', 'zz', ':HalShooterNavLastEditedFiles 10<cr>', 'Last 10 edited files')
  map('n', 'zl', ':HalShooterNavLastEditedFile<cr>', 'Last edited file')

  -- ============================================================
  -- REPO NAMESPACE (r prefix)
  -- ============================================================
  map('n', 'rl', ':HalShooterRepoOpenLastEditedFile<cr>', 'Last edited file in repo')

  -- ============================================================
  -- MASTERPLAN NAMESPACE (m prefix)
  -- ============================================================
  map('n', 'mm', ':HalShooterMasterplanOpen<cr>', 'Open docs/plans/masterplan.md')
  map('n', 'mf', ':HalShooterMasterplanFix<cr>', 'Fix masterplan (renumber, slugify, title)')
  map('n', 'md', ':HalShooterMasterplanMarkDone<cr>', 'Mark plan under cursor as done')

  -- ============================================================
  -- GIT NAMESPACE (g prefix)
  -- ============================================================
  map('n', 'gp', ':HalShooterGitPush<cr>', 'Git add/commit/push shotfiles')

  -- Git worktree subnamespace (gw prefix)
  for i = 0, 9 do
    map('n', 'gw' .. i, ':HalShooteroterGitWorktreeSwitchTo ' .. i .. '<cr>', 'Switch to worktree ' .. i)
  end
  for i = 1, 9 do
    map('n', 'gwd' .. i, ':HalShooterGitWorktreeOpenOil ' .. i .. '<cr>',
      'Open oil at parallel folder in worktree ' .. i)
  end
  map('n', 'gwl', ':HalShooteroterGitWorktreeLast<cr>', 'Switch to last worktree')
  map('n', 'gwm', ':HalShooteroterGitWorktreeToMain<cr>', 'Switch to main worktree')
  map('n', 'gww', ':HalShooteroterGitWorktreeSwitchTo<cr>', 'Pick worktree (telescope)')

  -- ============================================================
  -- SEND ALL (double prefix)
  -- ============================================================
  for i = 1, 9 do
    vim.keymap.set('n', prefix .. prefix .. tostring(i), ':HalShooterShotSendAll ' .. i .. '<cr>',
      vim.tbl_extend('force', opts, { desc = 'Send ALL to pane ' .. i }))
  end

  -- ============================================================
  -- SMART PASTE KEYMAPS (global, not under prefix)
  -- These override default paste to support clipboard images
  -- ============================================================
  if config.get('keymaps.smart_paste') ~= false then
    local clipboard = require('shooter.tools.clipboard_image')

    -- Normal mode: p and P for smart paste
    vim.keymap.set('n', 'p', clipboard.smart_paste_after,
      vim.tbl_extend('force', opts, { desc = 'Smart paste (image or text)' }))
    vim.keymap.set('n', 'P', clipboard.smart_paste_before,
      vim.tbl_extend('force', opts, { desc = 'Smart paste before (image or text)' }))

    -- Ctrl-V in insert mode only (normal mode <C-v> is visual block selection)
    vim.keymap.set('i', '<C-v>', function()
      if not clipboard.smart_paste_insert() then
        -- Use Ctrl-R + to paste from clipboard register (native vim way)
        local keys = vim.api.nvim_replace_termcodes('<C-r>+', true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      end
    end, vim.tbl_extend('force', opts, { desc = 'Smart paste from clipboard' }))
  end
end

return M

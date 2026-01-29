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
  map('n', 'n', ':ShooterShotfileNew<cr>', 'New shotfile')
  map('n', 's', ':ShooterShotNew<cr>', 'New shot')
  map('n', 'o', ':ShooterShotPicker<cr>', 'Open shots picker')
  map('n', 'v', ':ShooterShotfilePicker<cr>', 'Shotfile picker')
  map('n', 'l', ':ShooterShotfileLast<cr>', 'Last shotfile')
  map('n', 'L', ':ShooterRepoOpenLastEditedFile<cr>', 'Last edited file in repo')
  map('n', 'i', ':ShooterInbox<cr>', 'Open INBOX.md')
  map('n', '.', ':ShooterShotToggle<cr>', 'Toggle shot done')
  map('n', 'y', ':ShooterShotYank<cr>', 'Yank shot')
  map('n', 'z', ':ShooterNavLastEditedFiles 10<cr>', 'Last 10 edited files')
  map('n', 'e', ':ShooterShotExtractBlock<cr>', 'Extract block')
  map('n', 'E', ':ShooterShotExtractLine<cr>', 'Extract line')
  map('n', '?', ':ShooterCheatsheet<cr>', 'Cheatsheet')

  -- Shot navigation - root level for speed
  map('n', ']', ':ShooterShotNavNext<cr>', 'Next open shot')
  map('n', '[', ':ShooterShotNavPrev<cr>', 'Prev open shot')
  map('n', '}', ':ShooterShotNavNextSent<cr>', 'Next sent shot')
  map('n', '{', ':ShooterShotNavPrevSent<cr>', 'Prev sent shot')

  -- Send to pane (1-4) - root level for speed
  for i = 1, 4 do
    map('n', tostring(i), ':ShooterShotSend' .. i .. '<cr>', 'Send to pane ' .. i)
    map('v', tostring(i), ':ShooterShotSendVisual' .. i .. '<cr>', 'Send selection to pane ' .. i)
  end

  -- ============================================================
  -- SHOTFILE NAMESPACE (f prefix)
  -- ============================================================
  map('n', 'fn', ':ShooterShotfileNew<cr>', 'New shotfile')
  map('n', 'fN', ':ShooterShotfileNewInRepo<cr>', 'New in other repo')
  map('n', 'fp', ':ShooterShotfilePicker<cr>', 'Shotfile picker')
  map('n', 'fP', ':ShooterShotfilePickerAll<cr>', 'All repos picker')
  map('n', 'fl', ':ShooterShotfileLast<cr>', 'Last edited file')
  map('n', 'fr', ':ShooterShotfileRename<cr>', 'Rename current')
  map('n', 'fd', ':ShooterShotfileDelete<cr>', 'Delete current')
  map('n', 'fo', ':ShooterShotfileOpenPrompts<cr>', 'Oil prompts folder')
  map('n', 'fi', ':ShooterShotfileHistory<cr>', 'History (Oil)')

  -- Shotfile move commands (fm prefix)
  map('n', 'fma', ':ShooterShotfileMoveArchive<cr>', 'Move to archive')
  map('n', 'fmb', ':ShooterShotfileMoveBacklog<cr>', 'Move to backlog')
  map('n', 'fmd', ':ShooterShotfileMoveDone<cr>', 'Move to done')
  map('n', 'fmp', ':ShooterShotfileMovePrompts<cr>', 'Move to prompts')
  map('n', 'fmr', ':ShooterShotfileMoveReqs<cr>', 'Move to reqs')
  map('n', 'fmt', ':ShooterShotfileMoveTest<cr>', 'Move to test')
  map('n', 'fmw', ':ShooterShotfileMoveWait<cr>', 'Move to wait')
  map('n', 'fmg', ':ShooterShotfileMoveGitRoot<cr>', 'Move to git root')
  map('n', 'fmm', ':ShooterShotfileMovePicker<cr>', 'Fuzzy folder picker')

  -- ============================================================
  -- SHOT NAMESPACE (s prefix)
  -- ============================================================
  map('n', 'ss', ':ShooterShotNew<cr>', 'New shot')
  map('n', 'sS', ':ShooterShotNewWhisper<cr>', 'New shot + whisper')
  map('n', 'sd', ':ShooterShotDelete<cr>', 'Delete last shot')
  map('n', 's.', ':ShooterShotToggle<cr>', 'Toggle done')
  map('n', 'sm', ':ShooterShotMove<cr>', 'Move to another file')
  map('n', 'sM', ':ShooterShotMunition<cr>', 'Import from inbox')
  map('n', 'sy', ':ShooterShotYank<cr>', 'Yank shot to clipboard')
  map('n', 'se', ':ShooterShotExtractBlock<cr>', 'Extract block to new shot')
  map('n', 'sE', ':ShooterShotExtractLine<cr>', 'Extract line to new shot')
  map('n', 'sp', ':ShooterShotPicker<cr>', 'Open shots picker')

  -- Shot navigation
  map('n', 's]', ':ShooterShotNavNext<cr>', 'Next open shot')
  map('n', 's[', ':ShooterShotNavPrev<cr>', 'Prev open shot')
  map('n', 's}', ':ShooterShotNavNextSent<cr>', 'Next sent shot')
  map('n', 's{', ':ShooterShotNavPrevSent<cr>', 'Prev sent shot')
  map('n', 'sL', ':ShooterShotNavLatest<cr>', 'Latest sent')
  map('n', 'su', ':ShooterShotNavUndo<cr>', 'Undo sent marking')

  -- Shot send (also at root, but available with s prefix too)
  for i = 1, 4 do
    map('n', 's' .. i, ':ShooterShotSend' .. i .. '<cr>', 'Send to pane ' .. i)
    map('n', 'sR' .. i, ':ShooterShotResend' .. i .. '<cr>', 'Resend to pane ' .. i)
  end

  -- Shot queue
  for i = 1, 4 do
    map('n', 'sq' .. i, ':ShooterShotQueue' .. i .. '<cr>', 'Queue for pane ' .. i)
  end
  map('n', 'sqQ', ':ShooterShotQueueView<cr>', 'View queue')

  -- ============================================================
  -- TMUX NAMESPACE (t prefix)
  -- ============================================================
  map('n', 'tz', ':ShooterTmuxZoom<cr>', 'Zoom toggle')
  map('n', 'te', ':ShooterTmuxEdit<cr>', 'Edit pane in vim')
  map('n', 'tg', ':ShooterTmuxGit<cr>', 'Git status toggle')
  map('n', 'ti', ':ShooterTmuxLight<cr>', 'Light/dark toggle')
  map('n', 'to', ':ShooterTmuxKillOthers<cr>', 'Kill other panes')
  map('n', 'tr', ':ShooterTmuxReload<cr>', 'Reload session')
  map('n', 'td', ':ShooterTmuxDelete<cr>', 'Delete session')
  map('n', 'ts', ':ShooterTmuxSmug<cr>', 'Smug load')
  map('n', 'ty', ':ShooterTmuxYank<cr>', 'Yank pane to vim')
  map('n', 'tc', ':ShooterTmuxChoose<cr>', 'Choose session')
  map('n', 'tp', ':ShooterTmuxSwitch<cr>', 'Switch to last')
  map('n', 'tw', ':ShooterTmuxWatch<cr>', 'Watch pane')

  -- Pane toggle (t0-t9)
  for i = 0, 9 do
    map('n', 't' .. i, ':ShooterTmuxPaneToggle' .. i .. '<cr>', 'Toggle pane ' .. i)
  end

  -- ============================================================
  -- SUBPROJECT NAMESPACE (p prefix)
  -- ============================================================
  map('n', 'pn', ':ShooterSubprojectNew<cr>', 'New subproject')
  map('n', 'pl', ':ShooterSubprojectList<cr>', 'List subprojects')
  map('n', 'pe', ':ShooterSubprojectEnsure<cr>', 'Ensure standard folders')

  -- ============================================================
  -- TOOLS NAMESPACE (l prefix)
  -- ============================================================
  map('n', 'lt', ':ShooterToolToken<cr>', 'Token counter')
  map('n', 'lo', ':ShooterToolObsidian<cr>', 'Open in Obsidian')
  map('n', 'li', ':ShooterToolImages<cr>', 'Insert images')
  map('n', 'lw', ':ShooterTmuxWatch<cr>', 'Watch pane')
  map('n', 'lp', ':ShooterToolPrd<cr>', 'PRD list')
  map('n', 'lc', ':ShooterToolClipboardPaste<cr>', 'Paste clipboard image')
  map('n', 'lI', ':ShooterToolClipboardImages<cr>', 'Open images folder')

  -- ============================================================
  -- CFG NAMESPACE (c prefix)
  -- ============================================================
  map('n', 'cg', ':ShooterCfgGlobal<cr>', 'Edit global context')
  map('n', 'cp', ':ShooterCfgProject<cr>', 'Edit project context')
  map('n', 'ce', ':ShooterCfgPlugin<cr>', 'Edit shooter.lua plugin')
  map('n', 'cs', ':ShooterCfgShot<cr>', 'Shot picker config')
  map('n', 'cf', ':ShooterCfgShotfile<cr>', 'Shotfile picker config')

  -- ============================================================
  -- ANALYTICS NAMESPACE (a prefix)
  -- ============================================================
  map('n', 'aa', ':ShooterAnalyticsProject<cr>', 'Project analytics')
  map('n', 'aA', ':ShooterAnalyticsGlobal<cr>', 'Global analytics')

  -- ============================================================
  -- HELP NAMESPACE (h prefix)
  -- ============================================================
  map('n', 'hh', ':ShooterHelp<cr>', 'Show help')
  map('n', 'hH', ':ShooterHealth<cr>', 'Health check')
  map('n', 'hd', ':ShooterHelpDashboard<cr>', 'Dashboard')

  -- ============================================================
  -- QUICK FOLDER ACCESS (, prefix)
  -- ============================================================
  map('n', ',p', ':ShooterShotfileOpenPrompts<cr>', 'Open prompts folder')
  map('n', ',l', ':ShooterOpenPlans<cr>', 'Open plans folder')
  map('n', ',s', ':ShooterOpenShooterConfig<cr>', 'Open .shooter.nvim folder')

  -- ============================================================
  -- NAV NAMESPACE (z prefix) - Navigation commands
  -- ============================================================
  map('n', 'zz', ':ShooterNavLastEditedFiles 10<cr>', 'Last 10 edited files')
  map('n', 'zl', ':ShooterNavLastEditedFile<cr>', 'Last edited file')

  -- ============================================================
  -- REPO NAMESPACE (r prefix)
  -- ============================================================
  map('n', 'rl', ':ShooterRepoOpenLastEditedFile<cr>', 'Last edited file in repo')

  -- ============================================================
  -- SEND ALL (double prefix)
  -- ============================================================
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. prefix .. tostring(i), ':ShooterShotSendAll' .. i .. '<cr>',
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

    -- Ctrl-V in normal and insert mode
    vim.keymap.set('n', '<C-v>', function()
      if not clipboard.smart_paste_insert() then
        vim.cmd('normal! "+p')
      end
    end, vim.tbl_extend('force', opts, { desc = 'Smart paste from clipboard' }))

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

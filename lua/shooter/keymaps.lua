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
  map('n', 'N', ':ShoShotfileNew<cr>', 'New shotfile')
  map('n', 'n', ':ShoShotNew<cr>', 'New shot')
  map('n', 'o', ':ShoShotPicker<cr>', 'Open shots picker')
  map('n', 'v', ':ShoShotfilePicker<cr>', 'Shotfile picker')
  map('n', 'l', ':ShoShotfileLast<cr>', 'Last shotfile')
  map('n', 'L', ':ShoRepoOpenLastEditedFile<cr>', 'Last edited file in repo')
  map('n', 'i', ':ShoInbox<cr>', 'Open INBOX.md')
  map('n', '.', ':ShoShotToggle<cr>', 'Toggle shot done')
  map('n', 'y', ':ShoShotYank<cr>', 'Yank shot')
  map('n', 'z', ':ShoNavLastEditedFiles 10<cr>', 'Last 10 edited files')
  map('n', '?', ':ShoCheatsheet<cr>', 'Cheatsheet')

  -- Shot navigation - root level for speed
  map('n', ']', ':ShoShotNavNext<cr>', 'Next open shot')
  map('n', '[', ':ShoShotNavPrev<cr>', 'Prev open shot')
  map('n', '}', ':ShoShotNavNextSent<cr>', 'Next sent shot')
  map('n', '{', ':ShoShotNavPrevSent<cr>', 'Prev sent shot')

  -- Send to pane (1-4) - root level for speed
  for i = 1, 4 do
    map('n', tostring(i), ':ShoShotSend ' .. i .. '<cr>', 'Send to pane ' .. i)
    map('v', tostring(i), ':ShoShotSendVisual ' .. i .. '<cr>', 'Send selection to pane ' .. i)
  end

  -- ============================================================
  -- SHOTFILE NAMESPACE (f prefix)
  -- ============================================================
  map('n', 'fn', ':ShoShotfileNew<cr>', 'New shotfile')
  map('n', 'fN', ':ShoShotfileNewInRepo<cr>', 'New in other repo')
  map('n', 'fp', ':ShoShotfilePicker<cr>', 'Shotfile picker')
  map('n', 'fP', ':ShoShotfilePickerAll<cr>', 'All repos picker')
  map('n', 'fl', ':ShoShotfileLast<cr>', 'Last edited file')
  map('n', 'fr', ':ShoShotfileRename<cr>', 'Rename current')
  map('n', 'fd', ':ShoShotfileDelete<cr>', 'Delete current')
  map('n', 'fo', ':ShoShotfileOpenPrompts<cr>', 'Oil prompts folder')
  map('n', 'fs', ':ShoFileStats<cr>', 'File stats')
  map('n', 'fcf', ':ShoFileToggleFirstShotOfDayColoring<cr>', 'Toggle day markers')

  -- Shotfile move commands (fm prefix)
  map('n', 'fma', ':ShoShotfileMoveArchive<cr>', 'Move to archive')
  map('n', 'fmb', ':ShoShotfileMoveBacklog<cr>', 'Move to backlog')
  map('n', 'fmd', ':ShoShotfileMoveDone<cr>', 'Move to done')
  map('n', 'fmp', ':ShoShotfileMovePrompts<cr>', 'Move to prompts')
  map('n', 'fmr', ':ShoShotfileMoveReqs<cr>', 'Move to reqs')
  map('n', 'fmt', ':ShoShotfileMoveTest<cr>', 'Move to test')
  map('n', 'fmw', ':ShoShotfileMoveWait<cr>', 'Move to wait')
  map('n', 'fmg', ':ShoShotfileMoveGitRoot<cr>', 'Move to git root')
  map('n', 'fmm', ':ShoShotfileMovePicker<cr>', 'Fuzzy folder picker')

  -- ============================================================
  -- SHOT NAMESPACE (s prefix)
  -- ============================================================
  map('n', 'ss', ':ShoShotNew<cr>', 'New shot')
  map('n', 'sS', ':ShoShotNewWhisper<cr>', 'New shot + whisper')
  map('n', 'sd', ':ShoShotDelete<cr>', 'Delete last shot')
  map('n', 'sD', ':ShoShotDeleteCursor<cr>', 'Delete shot at cursor')
  map('n', 's.', ':ShoShotToggle<cr>', 'Toggle done')
  map('n', 'sm', ':ShoShotMove<cr>', 'Move to another file')
  map('n', 'sM', ':ShoShotMunition<cr>', 'Import from inbox')
  map('n', 'sy', ':ShoShotYank<cr>', 'Yank shot to clipboard')
  map('n', 'se', ':ShoShotExtractBlock<cr>', 'Extract block to new shot')
  map('n', 'sE', ':ShoShotExtractLine<cr>', 'Extract line to new shot')
  map('n', 'sp', ':ShoShotPicker<cr>', 'Open shots picker')
  map('n', 'sr', ':ShoShotsRenumber<cr>', 'Renumber shots')
  map('n', 'sC', ':ShoShotCreateFromClaude<cr>', 'Create shot from Claude')

  -- Shot navigation
  map('n', 's]', ':ShoShotNavNext<cr>', 'Next open shot')
  map('n', 's[', ':ShoShotNavPrev<cr>', 'Prev open shot')
  map('n', 's}', ':ShoShotNavNextSent<cr>', 'Next sent shot')
  map('n', 's{', ':ShoShotNavPrevSent<cr>', 'Prev sent shot')
  map('n', 'sL', ':ShoShotNavLatest<cr>', 'Latest sent')
  map('n', 'su', ':ShoShotNavUndo<cr>', 'Undo sent marking')
  map('n', 'sv', ':ShoShotViewResponse<cr>', 'View shot response')

  -- Shot send (also at root, but available with s prefix too)
  for i = 1, 4 do
    map('n', 's' .. i, ':ShoShotSend ' .. i .. '<cr>', 'Send to pane ' .. i)
    map('n', 'sR' .. i, ':ShoShotResend ' .. i .. '<cr>', 'Resend to pane ' .. i)
  end

  -- Shot queue
  for i = 1, 4 do
    map('n', 'sq' .. i, ':ShoShotQueue' .. i .. '<cr>', 'Queue for pane ' .. i)
  end
  map('n', 'sqQ', ':ShoShotQueueView<cr>', 'View queue')

  -- ============================================================
  -- TMUX NAMESPACE (t prefix)
  -- ============================================================
  map('n', 'tt', ':ShoTmuxTogglePanes<cr>', 'Toggle configured panes')
  map('n', 'tz', ':ShoTmuxZoom<cr>', 'Zoom toggle')
  map('n', 'te', ':ShoTmuxEdit<cr>', 'Edit pane in vim')
  map('n', 'tg', ':ShoTmuxGit<cr>', 'Git status toggle')
  map('n', 'ti', ':ShoTmuxLight<cr>', 'Light/dark toggle')
  map('n', 'to', ':ShoTmuxKillOthers<cr>', 'Kill other panes')
  map('n', 'tr', ':ShoTmuxReload<cr>', 'Reload session')
  map('n', 'td', ':ShoTmuxDelete<cr>', 'Delete session')
  map('n', 'ts', ':ShoTmuxSmug<cr>', 'Smug load')
  map('n', 'ty', ':ShoTmuxYank<cr>', 'Yank pane to vim')
  map('n', 'tc', ':ShoTmuxChoose<cr>', 'Choose session')
  map('n', 'tp', ':ShoTmuxSwitch<cr>', 'Switch to last')
  map('n', 'tw', ':ShoTmuxWatch<cr>', 'Watch pane')

  -- Pane toggle (t0-t9)
  for i = 0, 9 do
    map('n', 't' .. i, ':ShoTmuxPaneToggle' .. i .. '<cr>', 'Toggle pane ' .. i)
  end

  -- ============================================================
  -- SUBPROJECT NAMESPACE (p prefix)
  -- ============================================================
  map('n', 'pn', ':ShoSubprojectNew<cr>', 'New subproject')
  map('n', 'pl', ':ShoSubprojectList<cr>', 'List subprojects')
  map('n', 'pe', ':ShoSubprojectEnsure<cr>', 'Ensure standard folders')

  -- ============================================================
  -- TOOLS NAMESPACE (l prefix)
  -- ============================================================
  map('n', 'lt', ':ShoToolToken<cr>', 'Token counter')
  map('n', 'lo', ':ShoToolObsidian<cr>', 'Open in Obsidian')
  map('n', 'li', ':ShoToolImages<cr>', 'Insert images')
  map('n', 'lw', ':ShoTmuxWatch<cr>', 'Watch pane')
  map('n', 'lp', ':ShoToolPrd<cr>', 'PRD list')
  map('n', 'lc', ':ShoToolClipboardPaste<cr>', 'Paste clipboard image')
  map('n', 'lI', ':ShoToolClipboardImages<cr>', 'Open images folder')

  -- ============================================================
  -- CFG NAMESPACE (c prefix)
  -- ============================================================
  map('n', 'cg', ':ShoCfgGlobal<cr>', 'Edit global context')
  map('n', 'cp', ':ShoCfgProject<cr>', 'Edit project context')
  map('n', 'ce', ':ShoCfgPlugin<cr>', 'Edit shooter.lua plugin')
  map('n', 'cs', ':ShoCfgShot<cr>', 'Shot picker config')
  map('n', 'cf', ':ShoCfgShotfile<cr>', 'Shotfile picker config')
  map('n', 'cR', ':ShoCfgReload<cr>', 'Reload YAML config')
  map('n', 'cG', ':ShoCfgEditGlobal<cr>', 'Edit global YAML config')
  map('n', 'cL', ':ShoCfgEditLocal<cr>', 'Edit local YAML config')
  map('n', 'cF', ':ShoCfgFix<cr>', 'Fix YAML config')

  -- ============================================================
  -- ANALYTICS NAMESPACE (a prefix)
  -- ============================================================
  map('n', 'aa', ':ShoAnalyticsProject<cr>', 'Project analytics')
  map('n', 'aA', ':ShoAnalyticsGlobal<cr>', 'Global analytics')

  -- ============================================================
  -- HELP NAMESPACE (h prefix)
  -- ============================================================
  map('n', 'hh', ':ShoHelp<cr>', 'Show help')
  map('n', 'hH', ':ShoHealth<cr>', 'Health check')
  map('n', 'hd', ':ShoHelpDashboard<cr>', 'Dashboard')

  -- ============================================================
  -- QUICK FOLDER ACCESS (, prefix)
  -- ============================================================
  map('n', ',p', ':ShoShotfileOpenPrompts<cr>', 'Open prompts folder')
  map('n', ',l', ':ShoOpenPlans<cr>', 'Open plans folder')
  map('n', ',s', ':ShoOpenShoConfig<cr>', 'Open .shooter/config/nvim folder')

  -- ============================================================
  -- NAV NAMESPACE (z prefix) - Navigation commands
  -- ============================================================
  map('n', 'zz', ':ShoNavLastEditedFiles 10<cr>', 'Last 10 edited files')
  map('n', 'zl', ':ShoNavLastEditedFile<cr>', 'Last edited file')

  -- ============================================================
  -- REPO NAMESPACE (r prefix)
  -- ============================================================
  map('n', 'rl', ':ShoRepoOpenLastEditedFile<cr>', 'Last edited file in repo')

  -- ============================================================
  -- SEND ALL (double prefix)
  -- ============================================================
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. prefix .. tostring(i), ':ShoShotSendAll ' .. i .. '<cr>',
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

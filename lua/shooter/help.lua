-- Help display for shooter.nvim
-- Shows available commands and keybindings organized by namespace

local M = {}

-- Help text content organized by namespace
local help_text = [[
Shooter.nvim Commands (prefix: <space>)
========================================

CORE SHORTCUTS (root level for quick access)
  n         New shotfile          Create new shooter file
  s         New shot              Add new shot to current file
  o         Open shots picker     Telescope picker for open shots
  v         Shotfile picker       Telescope picker for shot files
  l         Last shotfile         Open last edited shotfile in repo
  .         Toggle done           Toggle shot done/open status
  z         Yank shot             Yank current shot to clipboard
  e         Extract block         Extract ### subtask block to new shot
  E         Extract line          Extract current line to new shot
  1-4       Send to pane          Send current shot to Claude pane #1-4

SHOTFILE NAMESPACE (f prefix)
  fn        New shotfile          Create new shooter file (= n)
  fN        New in repo           Create in another repo
  fp        Shotfile picker       Telescope picker (current repo) (= v)
  fP        All repos picker      Telescope picker (all repos)
  fl        Last file             Open last edited shotfile
  fr        Rename                Rename current shotfile
  fd        Delete                Delete current shotfile
  fo        Open prompts          Oil prompts folder
  fi        History               Open history directory in Oil

  MOVE COMMANDS (fm prefix)
  fma       Move to archive       Move file to prompts/archive
  fmb       Move to backlog       Move file to prompts/backlog
  fmd       Move to done          Move file to prompts/done
  fmp       Move to prompts       Move file to prompts root
  fmr       Move to reqs          Move file to prompts/reqs
  fmt       Move to test          Move file to prompts/test
  fmw       Move to wait          Move file to prompts/wait
  fmg       Move to git root      Move file/folder to git root
  fmm       Fuzzy picker          Move to any folder (fuzzy search)

SHOT NAMESPACE (s prefix)
  ss        New shot              Create new shot (= s)
  sS        New + whisper         Create shot and start voice recording
  sd        Delete                Delete last created shot
  s.        Toggle done           Toggle shot done/open status
  sm        Move shot             Move shot to another shotfile
  sM        Munition              Import tasks from inbox files
  sy        Yank shot             Yank current shot to clipboard (= z)
  se        Extract block         Extract ### subtask block (= e)
  sE        Extract line          Extract current line (= E)
  sp        Open shots picker     Telescope picker for open shots (= o)

  NAVIGATION
  s]        Next open shot        Jump to next open (undone) shot
  s[        Prev open shot        Jump to previous open shot
  s}        Next sent shot        Jump to next (newer) sent shot
  s{        Prev sent shot        Jump to previous (older) sent shot
  sL        Latest sent           Jump to most recently sent shot
  su        Undo sent             Undo the marking of latest sent shot

  SEND (s1-4 or just 1-4)
  s1-4      Send to pane          Send current shot to Claude pane #1-4

  RESEND
  sR1-4     Resend to pane        Resend latest shot to pane #1-4

  QUEUE
  sq1-4     Queue for pane        Add shot to queue for pane #1-4
  sqQ       View queue            Telescope picker for queued shots

TMUX NAMESPACE (t prefix)
  tz        Zoom toggle           Toggle current pane zoom
  te        Edit in vim           Edit pane content in vim
  tg        Git status            Toggle git status display
  ti        Light switch          Toggle light/dark theme
  to        Kill others           Kill all panes except current
  tr        Reload                Reload tmuxp session
  td        Delete session        Open session delete picker
  ts        Smug load             Load smug session
  ty        Yank to vim           Yank pane content to new vim buffer
  tc        Choose session        Open tmux session chooser tree
  tp        Switch last           Switch to last tmux client
  tw        Watch pane            Open maximized pane with shooter watch

  PANE TOGGLE (t0-9)
  t0-9      Toggle pane           Toggle visibility of tmux pane #0-9
                                  Hides pane to background, or shows again

SUBPROJECT NAMESPACE (p prefix)
  pn        New subproject        Create new subproject
  pl        List subprojects      List and select subproject
  pe        Ensure folders        Ensure standard folder structure exists

TOOLS NAMESPACE (l prefix)
  lt        Token counter         Count tokens in file using ttok
  lo        Open in Obsidian      Open current file in Obsidian app
  li        Insert images         Insert image references
  lw        Watch pane            Open watch pane (= tw)
  lp        PRD list              List tasks from plans/prd.json
  lc        Clipboard paste       Paste clipboard image to .shooter.nvim/images/
  lI        Images folder         Open clipboard images folder in Oil

CFG NAMESPACE (c prefix)
  cg        Global context        Edit global context file
  cp        Project context       Edit project context file
  ce        Plugin config         Edit shooter.lua plugin config
  cs        Shot picker config    Toggle shot picker vim mode
  cf        Shotfile config       Edit shotfile picker session config

ANALYTICS NAMESPACE (a prefix)
  aa        Project analytics     Show project shot analytics
  aA        Global analytics      Show global shot analytics

HELP NAMESPACE (h prefix)
  hh        Help                  Show this help message
  hH        Health                Run shooter health check
  hd        Dashboard             Open project dashboard

SEND ALL (double prefix)
  <space><space>1-4               Send ALL open shots to pane #1-4

FOLDER STRUCTURE
  plans/prompts/           <- new files created here (in-progress)
  plans/prompts/archive/   <- completed/archived
  plans/prompts/backlog/   <- future tasks
  plans/prompts/done/      <- finished tasks
  plans/prompts/reqs/      <- requirements
  plans/prompts/test/      <- testing
  plans/prompts/wait/      <- waiting/blocked

PROJECT SUPPORT
  If a 'projects/' folder exists at git root, shooter becomes project-aware:
  - <space>n shows project picker when at repo root
  - If cwd is inside projects/<name>/, that project is auto-detected
  - Files are created at projects/<name>/plans/prompts/
  - History paths include project: ~/.config/.../history/user/repo/project/...

CONTEXT FILES
  Global context:   ~/.config/shooter.nvim/shooter-context-global.md
  Project context:  <repo>/.shooter.nvim/shooter-context-project.md
  Plugin config:    ~/.config/nvim/lua/plugins/shooter.lua (lazy.nvim)

HISTORY
  ~/.config/shooter.nvim/history/<user>/<repo>/   <- Shot history per repo

Press 'q' to close this help window.
]]

-- Show help in a scratch buffer
function M.show()
  -- Create a scratch buffer
  vim.cmd('new')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false

  -- Try to set buffer name
  pcall(vim.api.nvim_buf_set_name, buf, '[ShooterHelp]')

  -- Split help text into lines
  local lines = {}
  for line in help_text:gmatch('[^\n]*') do
    table.insert(lines, line)
  end

  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  -- Map q to close
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
end

return M

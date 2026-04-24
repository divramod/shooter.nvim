-- Help display for shooter.nvim
-- Shows available commands and keybindings organized by namespace

local M = {}

-- Help text content organized by namespace
local help_text = [[
Shooter.nvim Commands (prefix: <space>)
========================================

CORE SHORTCUTS (root level for quick access)
  N         New shotfile          Create new shooter file
  n         New shot              Add new shot to current file
  o         Open shots picker     Telescope picker for open shots
  v         Shotfile picker       Telescope picker for shot files
  l         Last shotfile         Open last edited shotfile in repo
  L         Last file in repo     Open last edited file anywhere in repo
  i         Open INBOX.md         Open INBOX.md at git root
  .         Toggle done           Toggle shot done/open status
  y         Yank shot             Yank current shot to clipboard
  z         Last 10 edited        Picker over last 10 edited files
  x         Link picker (file)    Pick links from the current file
  X         Link picker (tmux)    Pick links from tmux window scrollback
  C         Hal config picker     Pick any hal plugin config file
  H         Hal plugin help       Show this help window
  ?         Cheatsheet            Show compact keymap cheatsheet
  [  ]      Prev/next open shot   Jump between undone shots
  {  }      Prev/next sent shot   Jump between sent shots
  1-9       Send to pane          Send current shot (or selection) to pane N

SHOTFILE NAMESPACE (f prefix)
  fn        New shotfile          Create new shooter file (= N)
  fN        New in repo           Create shotfile in another repo
  fp        Shotfile picker       Telescope picker (current repo) (= v)
  fP        All repos picker      Telescope picker (all repos)
  fl        Last file             Open last edited shotfile
  fr        Rename                Rename current shotfile
  fd        Delete                Delete current shotfile
  fo        Open prompts          Oil in prompts folder
  fs        File stats            Show per-file stats
  ff        Fix current           Fix title / empties / renumber / commit
  fa        Fix all               Walk every shotfile and apply full cleanup
  fM        Merge into            Merge current shotfile into another
  fcf       Toggle day markers    Toggle day-of-week coloring for first shot

  MOVE (fm prefix)
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
  ss        New shot              Create new shot (= n)
  sS        New + whisper         Create shot and start voice recording
  sd        Delete last           Delete last created shot
  sD        Delete at cursor      Delete shot at cursor
  s.        Toggle done           Toggle shot done/open status
  sm        Move shot             Move shot to another shotfile
  sM        Munition              Import tasks from inbox files
  sy        Yank shot             Yank current shot to clipboard (= y)
  se        Extract block         Extract ### subtask block to new shot
  sE        Extract line          Extract current line to new shot
  sp        Shots picker          Telescope picker for open shots (= o)
  sr        Renumber              Renumber all shots sequentially
  sC        From Claude           Create shot from Claude response
  sv        View response         View shot response

  NAVIGATION
  s]        Next open shot        Jump to next open (undone) shot
  s[        Prev open shot        Jump to previous open shot
  s}        Next sent shot        Jump to next (newer) sent shot
  s{        Prev sent shot        Jump to previous (older) sent shot
  sL        Latest sent           Jump to most recently sent shot
  su        Undo sent             Undo the marking of latest sent shot

  SEND / RESEND / QUEUE
  s1-9      Send to pane          Send current shot to pane N
  sR1-9     Resend to pane        Resend latest shot to pane N
  sq1-9     Queue for pane        Add shot to queue for pane N
  sqQ       View queue            Telescope picker for queued shots

SESSION NAMESPACE (sc prefix)
  sc1-9     Clear session N       Clear Claude session in pane N

BULLET NAMESPACE (b prefix)
  bf        File bullets          Bullet picker (current file)
  br        Repo bullets          Bullet picker (current repo)
  ba        All repos bullets     Bullet picker (all repos)

DOMAIN NAMESPACE (d prefix)
  dn        New domain            Create a new domain
  dmf       Move to domain        Move shotfile into a domain
  dr        Rename domain         Rename current domain

TMUX NAMESPACE (t prefix)
  tt        Toggle panes          Toggle configured panes
  tz        Zoom toggle           Toggle current pane zoom
  te        Edit in vim           Edit pane content in vim
  tg        Git status            Toggle git status display
  ti        Light/dark toggle     Toggle light/dark theme
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

PLAN NAMESPACE (p prefix) — masterplan + per-plan ops + pickers
  Everything plan-related lives under <space>p. Lowercase letters act
  on the plan referenced on the CURRENT LINE in masterplan.md;
  uppercase letters open a telescope picker across all plans.

  MASTERPLAN FILE OPS
  pm        Open masterplan       Open docs/plans/masterplan.md
                                  (runs Fix on open — always tidy)
  pf        Fix masterplan        Normalize title (# masterplan <repo> (<alias>)),
                                  ensure the 4 sections in order (in progress /
                                  next plans / backlog / done), renumber
                                  `## next plans` starting at max(docs/plans
                                  folders, started plans) + 1, slugify pre-paren
                                  names, preserve (description) suffix and
                                  indented child notes, and reconcile every
                                  plan's shotfile in
                                  .hal/util/shooter/shotfiles/docs/plans/
                                  (rename on drift, create if missing, adapt
                                  title to new name).
  pd        Mark done             Move plan under cursor to the top of
                                  `## done` with a timestamp, carrying its
                                  indented child notes along.

  PER-PLAN OPS (cursor on a plan line)
  pp        Open plan.md          Open docs/plans/<NNNN-slug>/plan.md
  pc        Open context.md       Open docs/plans/<NNNN-slug>/context.md
  ps        Open spec.md          Open docs/plans/<NNNN-slug>/spec.md
  pe        Edit plan shotfile    Open/rename/create the plan's shotfile
                                  under .hal/util/shooter/shotfiles/docs/plans/

  PICKERS (over all plans)
  pP        Pick plan.md          Telescope picker of docs/plans/**/plan.md
  pC        Pick context.md       Telescope picker of docs/plans/**/context.md
  pS        Pick spec.md          Telescope picker of docs/plans/**/spec.md

TOOLS NAMESPACE (l prefix)
  lt        Token counter         Count tokens in file using ttok
  lo        Open in Obsidian      Open current file in Obsidian app
  li        Insert images         Insert image references
  lw        Watch pane            Open watch pane (= tw)
  lp        PRD list              List tasks from plans/prd.json
  lc        Clipboard paste       Paste clipboard image
  lI        Images folder         Open clipboard images folder in Oil

CFG NAMESPACE (c prefix)
  cg        Global context        Edit global context file
  cp        Project context       Edit project context file
  ce        Plugin config         Edit shooter.lua plugin config
  cs        Shot picker config    Toggle shot picker vim mode
  cf        Shotfile config       Edit shotfile picker session config
  cR        Reload YAML config    Reload config.yaml and reapply syntax
  cG        Edit global YAML      Open ~/.config/shooter/nvim/config.yaml
  cL        Edit local YAML       Open <repo>/.shooter/cfg/nvim/config.yaml
  cF        Fix YAML config       Strip invalid keys, fill missing defaults

GIT NAMESPACE (g prefix)
  gp        Git push shotfiles    add/commit/push .hal/util/shooter/shotfiles
                                  and docs/ (title-fix + sync + push)

  WORKTREE (gw prefix)
  gw0-9     Switch worktree N     Switch to worktree slot N
  gwd1-9    Oil @ worktree N      Open oil at parallel folder in worktree N
  gwl       Last worktree         Switch to last worktree
  gwm       Main worktree         Switch to main worktree
  gww       Pick worktree         Telescope picker over worktrees

ANALYTICS NAMESPACE (A prefix)
  Ap        Project analytics     Show project shot analytics
  Aa        Global analytics      Show global shot analytics

HELP NAMESPACE (h prefix)
  hh        Help                  Show this help (= H)
  hH        Health                Run shooter health check
  hd        Dashboard             Open project dashboard

QUICK FOLDER ACCESS (, prefix)
  ,p        Prompts folder        Open .hal/util/shooter/shotfiles in Oil
  ,l        Plans folder          Open plans in Oil
  ,s        Shooter config        Open .shooter/config/nvim in Oil

NAV NAMESPACE (z prefix)
  zz        Last 10 edited        Picker over last 10 edited files
  zl        Last edited           Open the single last-edited file

REPO NAMESPACE (r prefix)
  rl        Last edited in repo   Open last edited file anywhere in repo

SEND ALL (double prefix)
  <space><space>1-9               Send ALL open shots to pane N

SMART PASTE (global, disable with keymaps.smart_paste = false)
  p         Smart paste after     Paste clipboard image, else normal paste
  P         Smart paste before    Paste before, else normal paste
  <C-v>     Clipboard paste       Insert mode: paste image or + register
  Images saved to: <repo>/.hal/util/shooter/tmp/image-pastes/clipboard_*.png

FOLDER STRUCTURE
  .hal/util/shooter/shotfiles/           <- shotfiles root
  .hal/util/shooter/shotfiles/docs/plans <- per-plan shotfiles (managed by pe/pf)
  .hal/util/shooter/shotfiles/archive/   <- completed/archived
  .hal/util/shooter/shotfiles/backlog/   <- future tasks
  .hal/util/shooter/shotfiles/done/      <- finished tasks
  .hal/util/shooter/shotfiles/reqs/      <- requirements
  .hal/util/shooter/shotfiles/test/      <- testing
  .hal/util/shooter/shotfiles/wait/      <- waiting/blocked
  docs/plans/masterplan.md               <- high-level plan index
  docs/plans/<NNNN-slug>/                <- per-plan folder with plan.md /
                                            context.md / spec.md

PROJECT SUPPORT
  If a 'projects/' folder exists at git root, shooter becomes project-aware:
  - <space>N shows project picker when at repo root
  - If cwd is inside projects/<name>/, that project is auto-detected
  - Files are created at projects/<name>/.hal/util/shooter/shotfiles/
  - History paths include project: ~/.config/.../history/user/repo/project/...

CONTEXT FILES
  Global context:   ~/.config/shooter/nvim/shooter-context-global.md
  Project context:  <repo>/.shooter/config/nvim/shooter-context-project.md
  Plugin config:    ~/.config/nvim/lua/plugins/shooter.lua (lazy.nvim)
  Global YAML cfg:  ~/.config/shooter/nvim/config.yaml
  Local YAML cfg:   <repo>/.shooter/cfg/nvim/config.yaml

HISTORY
  ~/.config/shooter/nvim/history/<user>/<repo>/   <- Shot history per repo

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
  pcall(vim.api.nvim_buf_set_name, buf, '[HalShooterHelp]')

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

-- Help display for shooter.nvim
-- Shows available commands and keybindings

local M = {}

-- Help text content
local help_text = [[
Shooter.nvim Commands (prefix: <space>)
========================================

CORE COMMANDS:
  d     Delete Last Shot  Delete the most recently created shot (highest number)
                          Only deletes if not already being worked on (no x marker)
  e     New Shot + Whisper  Create new shot and start voice recording
  g     Get Images        Insert image references (opens hal image pick)
  h     Help              Show this help message
  i     History           Open shot history for current repo (Oil)
  l     Last              Open last edited shooter file
  M     Munition          Import tasks from inbox files as new shots
                          First pick inbox file, then select tasks (- [ ] or # headers)
                          Multi-select with Tab/Space, Enter imports and deletes from source
  n     New               Create new shooter file
  N     New in Repo       Create new file in another repo (picker)
  o     Open Shots        Telescope picker for open shots (with multi-select)
                          In telescope: Tab/Space = select, c = clear selection
                            1-4 = send to claude, Enter = jump to shot
                            h = hide (keeps selection), q = quit (clears selection)
  s     New Shot          Add new shot at top of current file
  t     Telescope         Telescope picker for all shooter files
                          In telescope (normal mode):
                            a = archive, b = backlog, d = done
                            p = prompts, r = reqs, t = test, w = wait
                            dd = delete, Enter = open
  p     Oil               Open Oil file explorer in plans/prompts folder
  w     Write             Write all modified buffers

SEND TO CLAUDE (single shot):
  1-4                     Send current shot to claude pane #1-4
                          In shooter file: sends entire shot, marks with x and timestamp
                          Outside: sends current line (normal) or selection (visual)

SEND TO CLAUDE (multi-shot):
  <space>1-4              Send ALL open shots to claude pane #1-4
                          (double space = <space><space>1)

QUEUE COMMANDS:
  q1-4  Queue Shot        Add current shot to queue for pane #1-4
  Q     View Queue        Telescope picker to view and manage queued shots

MOVE COMMANDS (prefix: <space>m):
  ma    Archive           Move current file to prompts/archive
  mb    Backlog           Move current file to prompts/backlog
  md    Done              Move current file to prompts/done
  mg    Git Root          Move current file/folder to git root
  mp    Prompts           Move current file to prompts (in-progress)
  mr    Reqs              Move current file to prompts/reqs
  mt    Test              Move current file to prompts/test
  mw    Wait              Move current file to prompts/wait

NAVIGATION & STATUS:
  ]     Next Open Shot    Jump to next open (undone) shot
  [     Prev Open Shot    Jump to previous open shot
  }     Next Sent Shot    Jump to next (newer) sent shot by timestamp
  {     Prev Sent Shot    Jump to previous (older) sent shot by timestamp
  .     Toggle Done       Toggle shot done/open status (adds/removes x and timestamp)
  L     Latest Sent       Jump to most recently sent shot (by timestamp)
  u     Undo Latest Sent  Undo the marking of the latest sent shot
  H     Health Check      Run shooter health check

OTHER COMMANDS:
  P     PRD List          List all tasks from plans/prd.json with preview

FOLDER STRUCTURE:
  plans/prompts/           <- new files created here (in-progress)
  plans/prompts/archive/   <- completed/archived
  plans/prompts/backlog/   <- future tasks
  plans/prompts/done/      <- finished tasks
  plans/prompts/reqs/      <- requirements
  plans/prompts/test/      <- testing
  plans/prompts/wait/      <- waiting/blocked

CONTEXT & CONFIG:
  ec    Edit Config       Edit shooter.nvim config file (auto-detected)
  eg    Edit Global       Edit global context file
  ep    Edit Project      Edit project context file

  Config file:           ~/.config/nvim/lua/plugins/shooter.lua (lazy.nvim)
  Global context:        ~/.config/shooter.nvim/shooter-context-global.md
  Project context:       <repo>/.shooter.nvim/shooter-context-project.md

HISTORY:
  ~/.config/shooter.nvim/history/<user>/<repo>/        <- Shot history per repo

SOUND NOTIFICATIONS:
  Enable sound when shots are sent (disabled by default):
    sound = { enabled = true, file = '/System/Library/Sounds/Pop.aiff', volume = 0.5 }
  Test with :ShooterSoundTest

TROUBLESHOOTING:
  Shot marked but not sent?
    - Press 'u' (vim undo) immediately if you haven't made other edits
    - Or use <space>u to undo the latest sent shot marking any time

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

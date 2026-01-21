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
  l     Last              Open last edited shooter file
  n     New               Create new shooter file
  o     Open Shots        Telescope picker for open shots (with multi-select)
                          In telescope: Tab = select, 1-4 = send to claude, Enter = jump
  s     New Shot          Add new shot at top of current file
  t     Telescope         Telescope picker for all shooter files
                          In telescope (normal mode):
                            a = archive, b = backlog, d = done
                            p = prompts, r = reqs, t = test, w = wait
                            dd = delete, Enter = open
  p     Oil               Open Oil file explorer in plans/prompts folder
  w     Write             Write all modified buffers
  x     Quit              Write and quit current buffer

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

CONTEXT FILES:
  ~/.config/shooter.nvim/shooter-context-global.md     <- Global instructions
  <repo>/.shooter.nvim/shooter-context-project.md      <- Project-specific

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

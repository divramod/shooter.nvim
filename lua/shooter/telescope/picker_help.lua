-- Picker help display for shooter.nvim
-- Shows only shooter-specific keymaps in a clean popup

local M = {}

-- Shotfile picker keymaps
M.shotfile_keymaps = {
  { 'FOLDERS', nil },
  { '1 / a', 'toggle: archive' },
  { '2 / b', 'toggle: backlog' },
  { '3 / t', 'toggle: done' },
  { '4 / e', 'toggle: reqs' },
  { '5 / w', 'toggle: wait' },
  { '6 / f', 'toggle: prompts' },
  { 'A', 'toggle all folders' },
  { 'SESSION', nil },
  { 'ss', 'save session' },
  { 'sl', 'load session' },
  { 'sn', 'new session' },
  { 'sd', 'delete session' },
  { 'sr', 'rename session' },
  { 'S', 'edit session YAML' },
  { 'FILTER & SORT', nil },
  { 'P', 'project picker' },
  { 's', 'sort picker' },
  { 'L', 'toggle layout' },
  { 'ACTIONS', nil },
  { 'n', 'new shotfile' },
  { 'l', 'open last edited' },
  { 'R', 'rename file' },
  { '<CR>', 'open file' },
  { 'MOVE (m prefix)', nil },
  { 'ma', 'move to archive' },
  { 'mb', 'move to backlog' },
  { 'md', 'move to done' },
  { 'mr', 'move to reqs' },
  { 'mw', 'move to wait' },
  { 'mp', 'move to prompts' },
  { 'NAVIGATION', nil },
  { '<C-n>', 'next result' },
  { '<C-p>', 'previous result' },
  { '<C-c>', 'close picker' },
  { '?', 'show this help' },
}

-- Open shots picker keymaps
M.shots_keymaps = {
  { 'SEND', nil },
  { '1-4', 'send to pane #' },
  { 'SELECT', nil },
  { '<Tab>', 'toggle selection' },
  { '<Space>', 'toggle + next' },
  { 'c', 'clear selection' },
  { 'ACTIONS', nil },
  { 'n', 'new shotfile' },
  { 'd', 'delete shot' },
  { '<CR>', 'jump to shot' },
  { 'h', 'hide (save selection)' },
  { 'NAVIGATION', nil },
  { '<C-n>', 'next result' },
  { '<C-p>', 'previous result' },
  { 'q', 'close picker' },
  { '<C-c>', 'close picker' },
}

-- Project picker keymaps
M.project_keymaps = {
  { 'SELECT', nil },
  { '<Tab>', 'toggle project' },
  { '<Space>', 'toggle project' },
  { '<CR>', 'apply selection' },
  { 'ACTIONS', nil },
  { 'n', 'new shotfile' },
  { 'l', 'open last edited' },
  { 'L', 'open latest sent' },
  { 'S', 'edit session YAML' },
  { 'NAVIGATION', nil },
  { '<C-n>', 'next result' },
  { '<C-p>', 'previous result' },
  { 'q', 'go back' },
  { '<C-c>', 'go back / normal mode' },
}

-- Sort picker keymaps
M.sort_keymaps = {
  { 'TOGGLE', nil },
  { '<Tab>', 'enable/disable' },
  { '<Space>', 'enable/disable' },
  { 'PRIORITY', nil },
  { '+', 'increase priority' },
  { '-', 'decrease priority' },
  { 'd', 'toggle direction' },
  { '<CR>', 'apply changes' },
  { 'ACTIONS', nil },
  { 'n', 'new shotfile' },
  { 'l', 'open last edited' },
  { 'L', 'open latest sent' },
  { 'S', 'edit session YAML' },
  { 'NAVIGATION', nil },
  { '<C-n>', 'next result' },
  { '<C-p>', 'previous result' },
  { 'q', 'go back (discard)' },
  { '<C-c>', 'go back / normal mode' },
}

-- Show help popup for a given keymap set
function M.show(keymaps, title)
  title = title or 'Keymaps'
  local lines = { title, string.rep('─', #title) }
  local max_key_len = 0
  for _, km in ipairs(keymaps) do
    if km[2] and #km[1] > max_key_len then max_key_len = #km[1] end
  end

  for _, km in ipairs(keymaps) do
    local key, desc = km[1], km[2]
    if desc then
      table.insert(lines, string.format('  %-' .. max_key_len .. 's  %s', key, desc))
    else
      table.insert(lines, '')
      table.insert(lines, key .. ':')
    end
  end
  table.insert(lines, '')
  table.insert(lines, 'Press q or <Esc> to close')

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = 40
  local height = #lines
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
  })

  local function close() pcall(vim.api.nvim_win_close, win, true) end
  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true })
end

function M.show_shotfile_help() M.show(M.shotfile_keymaps, 'Shotfile Picker') end
function M.show_shots_help() M.show(M.shots_keymaps, 'Open Shots Picker') end
function M.show_project_help() M.show(M.project_keymaps, 'Project Picker') end
function M.show_sort_help() M.show(M.sort_keymaps, 'Sort Picker') end

return M

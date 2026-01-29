-- Cheatsheet display for shooter.nvim
-- Shows all keymaps in a compact multi-column floating window

local M = {}

-- Cheatsheet data: { section, { key, desc }, ... }
M.sections = {
  { 'CORE (root level)', {
    { 'n', 'New shotfile' }, { 's', 'New shot' }, { 'o', 'Open shots picker' },
    { 'v', 'Shotfile picker' }, { 'l', 'Last shotfile' }, { 'L', 'Last edited in repo' },
    { 'i', 'INBOX.md' }, { '.', 'Toggle done' }, { 'y', 'Yank shot' },
    { 'z', 'Last 10 files' }, { 'e', 'Extract block' }, { 'E', 'Extract line' },
    { '[', 'Prev open shot' }, { ']', 'Next open shot' },
    { '{', 'Prev sent shot' }, { '}', 'Next sent shot' },
    { '1-4', 'Send to pane' }, { '<space>1-4', 'Send ALL' },
  }},
  { 'SHOTFILE (f)', {
    { 'fn', 'New shotfile' }, { 'fN', 'New in repo' }, { 'fp', 'Picker' },
    { 'fP', 'All repos picker' }, { 'fl', 'Last file' }, { 'fr', 'Rename' },
    { 'fd', 'Delete' }, { 'fo', 'Oil prompts' }, { 'fi', 'History' },
  }},
  { 'MOVE (fm)', {
    { 'fma', 'archive' }, { 'fmb', 'backlog' }, { 'fmd', 'done' },
    { 'fmp', 'prompts' }, { 'fmr', 'reqs' }, { 'fmt', 'test' },
    { 'fmw', 'wait' }, { 'fmg', 'git root' }, { 'fmm', 'fuzzy' },
  }},
  { 'SHOT (s)', {
    { 'ss', 'New shot' }, { 'sS', 'New + whisper' }, { 'sd', 'Delete last' },
    { 's.', 'Toggle done' }, { 'sm', 'Move shot' }, { 'sM', 'Munition' },
    { 'sy', 'Yank' }, { 'se', 'Extract block' }, { 'sE', 'Extract line' },
    { 'sp', 'Shots picker' }, { 'sr', 'Renumber' }, { 'sL', 'Latest sent' },
    { 'su', 'Undo sent' }, { 's1-4', 'Send to pane' }, { 'sR1-4', 'Resend' },
    { 'sq1-4', 'Queue' }, { 'sqQ', 'View queue' },
  }},
  { 'TMUX (t)', {
    { 'tz', 'Zoom toggle' }, { 'te', 'Edit in vim' }, { 'tg', 'Git status' },
    { 'ti', 'Light switch' }, { 'to', 'Kill others' }, { 'tr', 'Reload' },
    { 'td', 'Delete session' }, { 'ts', 'Smug load' }, { 'ty', 'Yank to vim' },
    { 'tc', 'Choose session' }, { 'tp', 'Switch last' }, { 'tw', 'Watch pane' },
    { 't0-9', 'Toggle pane' },
  }},
  { 'SUBPROJECT (p)', {
    { 'pn', 'New' }, { 'pl', 'List' }, { 'pe', 'Ensure folders' },
  }},
  { 'TOOLS (l)', {
    { 'lt', 'Token counter' }, { 'lo', 'Obsidian' }, { 'li', 'Images' },
    { 'lw', 'Watch pane' }, { 'lp', 'PRD list' },
    { 'lc', 'Clipboard paste' }, { 'lI', 'Images folder' },
  }},
  { 'CFG (c)', {
    { 'cg', 'Global context' }, { 'cp', 'Project context' }, { 'ce', 'Plugin config' },
    { 'cs', 'Shot picker cfg' }, { 'cf', 'Shotfile cfg' },
  }},
  { 'ANALYTICS (a)', {
    { 'aa', 'Project' }, { 'aA', 'Global' },
  }},
  { 'HELP (h)', {
    { 'hh', 'Help' }, { 'hH', 'Health check' }, { 'hd', 'Dashboard' },
  }},
  { 'FOLDERS (,)', {
    { ',p', 'Prompts' }, { ',l', 'Plans' }, { ',s', '.shooter.nvim' },
  }},
}

-- Render sections into lines for display
local function render(sections, col_width, num_cols)
  -- Build blocks: each section becomes { title_line, entry_lines... }
  local blocks = {}
  for _, sec in ipairs(sections) do
    local block = { title = sec[1], entries = {} }
    for _, entry in ipairs(sec[2]) do
      table.insert(block.entries, string.format('  %-8s %s', entry[1], entry[2]))
    end
    table.insert(blocks, block)
  end

  -- Distribute blocks across columns (greedy fill)
  local columns = {}
  for _ = 1, num_cols do table.insert(columns, {}) end
  local col_heights = {}
  for i = 1, num_cols do col_heights[i] = 0 end

  for _, block in ipairs(blocks) do
    -- Find shortest column
    local min_col, min_h = 1, col_heights[1]
    for i = 2, num_cols do
      if col_heights[i] < min_h then min_col, min_h = i, col_heights[i] end
    end
    -- Add block: 1 for title + entries + 1 blank
    local block_height = 1 + #block.entries + 1
    col_heights[min_col] = col_heights[min_col] + block_height
    table.insert(columns[min_col], block)
  end

  -- Render columns into lines
  local max_height = math.max(unpack(col_heights))
  local lines = {}
  for row = 1, max_height do
    local parts = {}
    for c = 1, num_cols do
      parts[c] = string.rep(' ', col_width)
    end

    -- Map row to block line in each column
    for c = 1, num_cols do
      local y = 0
      for _, block in ipairs(columns[c]) do
        y = y + 1
        if row == y then
          local title = '  ' .. block.title
          parts[c] = title .. string.rep(' ', math.max(0, col_width - #title))
        end
        for _, entry in ipairs(block.entries) do
          y = y + 1
          if row == y then
            parts[c] = entry .. string.rep(' ', math.max(0, col_width - #entry))
          end
        end
        y = y + 1 -- blank line after block
      end
    end
    table.insert(lines, table.concat(parts, '  '))
  end

  return lines
end

-- Show cheatsheet in floating window
function M.show()
  local col_width = 30
  local num_cols = 3
  local total_width = col_width * num_cols + (num_cols - 1) * 2

  local lines = render(M.sections, col_width, num_cols)
  -- Add header
  local title = 'Shooter.nvim Cheatsheet (prefix: <space>)'
  local header = {
    title,
    string.rep('─', total_width),
  }
  for i = #header, 1, -1 do table.insert(lines, 1, header[i]) end
  table.insert(lines, '')
  table.insert(lines, string.format('%s  press q/Esc to close', string.rep(' ', 30)))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = 'nofile'

  local height = math.min(#lines, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = total_width,
    height = height,
    col = math.floor((vim.o.columns - total_width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
  })

  -- Highlight section titles
  for i, line in ipairs(lines) do
    if line:match('^  %u') and not line:match('^  %u.*%l.*%l.*%s%s') then
      vim.api.nvim_buf_add_highlight(buf, -1, 'Title', i - 1, 0, -1)
    end
  end
  -- Highlight header
  vim.api.nvim_buf_add_highlight(buf, -1, 'Title', 0, 0, -1)

  local function close() pcall(vim.api.nvim_win_close, win, true) end
  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true })
end

return M

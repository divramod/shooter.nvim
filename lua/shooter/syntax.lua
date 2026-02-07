-- Syntax highlighting for shooter.nvim
-- Highlights shot headers in prompt files

local M = {}

-- Define highlight groups from config
local function define_highlights()
  local config = require('shooter.config')
  local open_shot = config.get('highlight.open_shot') or {}
  local latest_sent = config.get('highlight.latest_sent_shot') or {}

  -- Default: black text on light orange background (avoids search highlight confusion)
  vim.api.nvim_set_hl(0, 'ShooterOpenShot', {
    fg = open_shot.fg or '#000000',
    bg = open_shot.bg or '#ffb347',
    bold = open_shot.bold ~= false, -- default true
  })

  -- Green background for the most recently sent shot
  vim.api.nvim_set_hl(0, 'ShooterLatestSentShot', {
    fg = latest_sent.fg or '#000000',
    bg = latest_sent.bg or '#77dd77',
    bold = latest_sent.bold ~= false, -- default true
  })

  -- Lighter green for done shots without @shot- reference (manually marked done)
  local done_shot = config.get('highlight.done_shot') or {}
  vim.api.nvim_set_hl(0, 'ShooterDoneShot', {
    fg = done_shot.fg or '#555555',
    bg = done_shot.bg or '#c8e6c9',
    bold = done_shot.bold or false, -- default not bold
  })
end

-- Check if a line is a fenced code block delimiter (not inline code)
-- Fenced code block: starts with ``` and does NOT have closing ``` on same line
local function is_fence_delimiter(line)
  if not line:match('^%s*```') then return false end
  local _, count = line:gsub('```', '')
  return count == 1  -- Only one ``` sequence = fence delimiter
end

-- Check if a line number is inside a code block
local function is_in_code_block(bufnr, line_num)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_num, false)
  local in_block = false
  for _, line in ipairs(lines) do
    if is_fence_delimiter(line) then
      in_block = not in_block
    end
  end
  return in_block
end

-- Apply syntax highlighting to current buffer
local function apply_syntax(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  pcall(vim.fn.clearmatches)

  local config = require('shooter.config')
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find the latest SENT shot (actually fired to a pane, identified by @shot- reference)
  local latest_sent_line = nil
  local latest_timestamp = nil
  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) and line:match('@shot%-') then
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if ts and (not latest_timestamp or ts > latest_timestamp) then
        latest_timestamp = ts
        latest_sent_line = i
      end
    end
  end

  -- Highlight shot headers: open (orange), latest sent (green), done without ref (light green)
  local exec_pattern = config.get('patterns.executed_shot_header')
  for i, line in ipairs(lines) do
    if not is_in_code_block(bufnr, i) then
      if i == latest_sent_line then
        vim.fn.matchaddpos('ShooterLatestSentShot', { { i } }, 10)
      elseif line:match('^##%s+shot%s+[%d%?]+') then
        vim.fn.matchaddpos('ShooterOpenShot', { { i } }, -1)
      elseif line:match(exec_pattern) and not line:match('@shot%-') then
        vim.fn.matchaddpos('ShooterDoneShot', { { i } }, -1)
      end
    end
  end
end

-- Check if file is a prompts file (not Oil buffer, must be actual .md file in .shooter/shotfiles)
local function is_prompts_file(filepath)
  -- Exclude Oil buffers
  if filepath:match('^oil://') then return false end
  -- Must be a .md file in .shooter/shotfiles folder (including subdirectories like backlog/, archive/, etc.)
  return filepath:match('.shooter/shotfiles/.+%.md$') ~= nil
end

-- Setup autocommands for syntax highlighting
function M.setup()
  define_highlights()

  local group = vim.api.nvim_create_augroup('ShooterSyntax', { clear = true })

  -- Apply highlighting when entering prompts files
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      -- Only apply to markdown files in .shooter/shotfiles (not oil, not other filetypes)
      if ft == 'markdown' and is_prompts_file(filepath) then
        apply_syntax(ev.buf)
      else
        pcall(vim.fn.clearmatches)
      end
    end,
  })

  -- Clear matches when entering ANY non-prompts buffer (catches Oil, etc.)
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      -- If not a prompts file, clear window matches
      if not is_prompts_file(filepath) then
        pcall(vim.fn.clearmatches)
      end
    end,
  })

  -- Reapply when text changes (to handle code block additions/removals)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      if ft == 'markdown' and is_prompts_file(filepath) then
        apply_syntax(ev.buf)
      end
    end,
  })

  -- Reapply on colorscheme change
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      define_highlights()
    end,
  })
end

return M

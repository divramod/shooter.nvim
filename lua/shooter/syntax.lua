-- Syntax highlighting for shooter.nvim
-- Highlights shot headers in prompt files

local M = {}

-- Define highlight groups from config
local function define_highlights()
  local config = require('shooter.config')
  local open_shot = config.get('highlight.open_shot') or {}

  -- Default: black text on light orange background (avoids search highlight confusion)
  vim.api.nvim_set_hl(0, 'ShooterOpenShot', {
    fg = open_shot.fg or '#000000',
    bg = open_shot.bg or '#ffb347',
    bold = open_shot.bold ~= false, -- default true
  })
end

-- Check if a line number is inside a code block
local function is_in_code_block(bufnr, line_num)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_num, false)
  local in_block = false
  for _, line in ipairs(lines) do
    if line:match('^```') then
      in_block = not in_block
    end
  end
  return in_block
end

-- Apply syntax highlighting to current buffer
local function apply_syntax(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  pcall(vim.fn.clearmatches)

  -- Find all shot headers and add matches only for those outside code blocks
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match('^##%s+shot%s+[%d%?]+') and not is_in_code_block(bufnr, i) then
      -- matchaddpos uses 1-indexed line numbers
      vim.fn.matchaddpos('ShooterOpenShot', { { i } }, -1)
    end
  end
end

-- Check if file is a prompts file (not Oil buffer, must be actual .md file in plans/prompts)
local function is_prompts_file(filepath)
  -- Exclude Oil buffers
  if filepath:match('^oil://') then return false end
  -- Must be a .md file in plans/prompts folder
  return filepath:match('plans/prompts/[^/]+%.md$') ~= nil
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
      -- Only apply to markdown files in plans/prompts (not oil, not other filetypes)
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

-- Syntax highlighting for shooter.nvim
-- Highlights shot headers in prompt files

local M = {}

-- Define highlight groups
local function define_highlights()
  -- Open shot: yellow-ish background (done shots not highlighted)
  vim.api.nvim_set_hl(0, 'ShooterOpenShot', {
    bg = '#3d3d00',
    fg = '#ffff00',
    bold = true,
  })
end

-- Apply syntax highlighting to current buffer
local function apply_syntax(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Clear existing matches for this buffer
  pcall(vim.fn.clearmatches)

  -- Add match for open shots only: ## shot N (done shots not highlighted)
  vim.fn.matchadd('ShooterOpenShot', '^##\\s\\+shot\\s\\+\\d\\+.*$')
end

-- Check if file is a prompts file
local function is_prompts_file(filepath)
  return filepath:match('plans/prompts') ~= nil
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
      if is_prompts_file(filepath) then
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

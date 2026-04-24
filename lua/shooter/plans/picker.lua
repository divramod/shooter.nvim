-- Telescope pickers over docs/plans/**/<basename>.md files.
-- Used by HalShooterPlanPickerPlan / PlanPickerContext / PlanPickerSpec.

local M = {}

-- Recursively find all files named `<basename>.md` under `<git_root>/docs/plans`.
-- Returns list of absolute paths sorted by relative path.
function M.find(git_root, basename)
  if not git_root or git_root == '' then return {} end
  local root = git_root .. '/docs/plans'
  if vim.fn.isdirectory(root) ~= 1 then return {} end

  local cmd = {
    'find', root, '-type', 'f', '-name', basename .. '.md',
  }
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then return {} end
  table.sort(out)
  return out
end

-- Open a telescope picker of the matches and edit the selected file.
function M.open(git_root, basename)
  local paths = M.find(git_root, basename)
  if #paths == 0 then
    require('shooter.utils').echo(
      string.format('No %s.md files under docs/plans/', basename))
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers = require('telescope.previewers')
  local utils = require('shooter.utils')

  local prefix = git_root .. '/docs/plans/'
  pickers.new({}, {
    prompt_title = 'Plans: ' .. basename .. '.md',
    finder = finders.new_table({
      results = paths,
      entry_maker = function(path)
        local rel = path:sub(#prefix + 1)
        return { value = path, display = rel, ordinal = rel, path = path }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = basename .. '.md',
      define_preview = function(self, entry)
        local content = utils.read_file(entry.path) or ''
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
          vim.split(content, '\n'))
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    }),
    layout_strategy = 'vertical',
    layout_config = { width = 0.9, height = 0.9, preview_height = 0.5 },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.path then
          vim.cmd('edit ' .. vim.fn.fnameescape(entry.path))
        end
      end)
      return true
    end,
  }):find()
end

return M

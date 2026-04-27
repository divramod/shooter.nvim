-- Telescope picker for worktrees.
-- Pulled out of shooter/tools/git_worktree.lua during plan 0001 phase 004 T007.

local repo = require('shooter.tools.git_worktree.repo')
local list = require('shooter.tools.git_worktree.list')
local switch = require('shooter.tools.git_worktree.switch')

local M = {}

---@param worktrees? table[]
function M.pick_worktree(worktrees)
  worktrees = worktrees or list.get_numbered_worktrees()

  if #worktrees == 0 then return end

  local ok, _ = pcall(require, 'telescope')
  if not ok then return end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local entries = {}
  local main_path = list.get_main_worktree()
  if main_path then
    table.insert(entries, { name = 'main', path = main_path })
  end
  for _, wt in ipairs(worktrees) do
    table.insert(entries, wt)
  end

  local _, current_root = repo.get_repo_name()

  pickers.new({}, {
    prompt_title = 'Git Worktrees',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        local marker = ''
        if current_root and entry.path == current_root then
          marker = ' (CURRENT)'
        end
        local display = entry.name .. '  ' .. entry.path .. marker
        return { value = entry, display = display, ordinal = entry.name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      require('shooter.keymaps.picker').setup_nav_keymaps(map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          switch.switch_to_worktree(selection.value.path)
        end
      end)
      return true
    end,
  }):find()
end

return M

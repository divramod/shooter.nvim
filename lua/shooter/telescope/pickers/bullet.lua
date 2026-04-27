-- Bullet picker — current file / current repo / all repos.
local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local utils = require('shooter.utils')
local previewers_mod = require('shooter.telescope.previewers')
local helpers = require('shooter.telescope.helpers')
local recency = require('shooter.telescope.recency')

local function get_repo_slug()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error == 0 and #root > 0 then
    return vim.fn.fnamemodify(root[1], ':t')
  end
  return nil
end

local function create_bullet_picker(bullet_files, title)
  if #bullet_files == 0 then
    utils.echo('No bullet files found')
    return nil
  end

  local now = os.time()
  for _, e in ipairs(bullet_files) do
    e.display = recency.append_age(e.display, e._mtime, now)
  end

  local picker_instance = pickers.new({}, {
    prompt_title = title,
    layout_strategy = 'vertical',
    layout_config = { width = 0.95, height = 0.9, preview_height = 0.5 },
    finder = finders.new_table({
      results = bullet_files,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      require('shooter.keymaps.picker').setup_nav_keymaps(map)
      map('n', '<C-c>', actions.close, { desc = 'close' })
      map('n', 'q', actions.close, { desc = 'close' })

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value and entry.value.path then
          vim.cmd('edit ' .. vim.fn.fnameescape(entry.value.path))
        end
      end)

      return true
    end,
  })
  return picker_instance
end

function M.list_bullets_current_file()
  local repo_slug = get_repo_slug()
  if not repo_slug then
    utils.echo('Not in a git repo')
    return nil
  end
  local filepath = vim.fn.expand('%:p')
  local basename = vim.fn.fnamemodify(filepath, ':t:r')
  local bullet_files = helpers.get_bullet_files({
    scope = 'file',
    repo_slug = repo_slug,
    shotfile_basename = basename,
  })
  return create_bullet_picker(bullet_files, 'Bullets: ' .. basename)
end

function M.list_bullets_current_repo()
  local repo_slug = get_repo_slug()
  if not repo_slug then
    utils.echo('Not in a git repo')
    return nil
  end
  local bullet_files = helpers.get_bullet_files({
    scope = 'repo',
    repo_slug = repo_slug,
  })
  return create_bullet_picker(bullet_files, 'Bullets: ' .. repo_slug)
end

function M.list_bullets_all_repos()
  local bullet_files = helpers.get_bullet_files({ scope = 'all' })
  return create_bullet_picker(bullet_files, 'Bullets: All Repos')
end

return M

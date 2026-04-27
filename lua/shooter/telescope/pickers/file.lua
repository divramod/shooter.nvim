-- File picker engine: shotfile + plan + project-aware listing with session
-- filter/sort, keymaps, and inline new-shotfile-from-prompt creation.
local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local utils = require('shooter.utils')
local previewers_mod = require('shooter.telescope.previewers')
local helpers = require('shooter.telescope.helpers')
local session = require('shooter.session')
local session_filter = require('shooter.session.filter')
local session_sort = require('shooter.session.sort')
local session_picker = require('shooter.session.picker')
local shooter_config = require('shooter.config')
local recency = require('shooter.telescope.recency')
local title_mod = require('shooter.telescope.pickers.title')
local keymaps = require('shooter.telescope.pickers.keymaps')

local function create_file_picker(opts, get_files_fn, title_prefix, git_root_override)
  opts = opts or {}
  local files_mod = require('shooter.core.files')
  local git_root = git_root_override or files_mod.get_git_root()

  session.reload_from_disk()
  session_sort.clear_cache()

  local all_files = get_files_fn()
  local current = session.get_current_session()
  local filtered = session_filter.apply_filters(all_files, current, git_root)
  local sorted = session_sort.sort_files(filtered, current)
  local now = os.time()
  for _, e in ipairs(sorted) do
    if not e._mtime then
      e._mtime = recency.file_mtime(e.path)
    end
    e.display = recency.append_age(e.display, e._mtime, now)
  end

  local title = title_mod.build(title_prefix)
  if #sorted == 0 then
    title = title .. ' (no matching files)'
  end

  local function refresh_picker(prompt_bufnr)
    session_sort.clear_cache()
    local new_files = get_files_fn()
    local new_current = session.get_current_session()
    local new_filtered = session_filter.apply_filters(new_files, new_current, git_root)
    local new_sorted = session_sort.sort_files(new_filtered, new_current)
    local refresh_now = os.time()
    for _, e in ipairs(new_sorted) do
      if not e._mtime then
        e._mtime = recency.file_mtime(e.path)
      end
      e.display = recency.append_age(e.display, e._mtime, refresh_now)
    end
    local picker = action_state.get_current_picker(prompt_bufnr)
    picker.prompt_border:change_title(title_mod.build(title_prefix))
    picker:refresh(finders.new_table({
      results = new_sorted,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }), { reset_prompt = false })
  end

  local vim_mode = current.vimMode and current.vimMode.shotfilePicker or 'insert'
  local initial_mode = opts.initial_mode or vim_mode
  local layout = current.layout or 'vertical'
  local layout_config = layout == 'vertical'
    and { width = 0.95, height = 0.9, preview_height = 0.5 }
    or { width = 0.95, preview_width = 0.5 }

  local picker_instance = pickers.new(opts, {
    prompt_title = title,
    layout_strategy = layout,
    layout_config = layout_config,
    initial_mode = initial_mode,
    finder = finders.new_table({
      results = sorted,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      keymaps.setup_folder_mappings(prompt_bufnr, map, refresh_picker)
      keymaps.setup_session_mappings(prompt_bufnr, map, refresh_picker, M.list_all_files)

      map('n', 'P', function()
        actions.close(prompt_bufnr)
        session_picker.show_project_picker(function()
          M.list_all_files({ initial_mode = 'normal' }):find()
        end)
      end, { desc = 'filter: by project' })

      map('n', 's', function()
        actions.close(prompt_bufnr)
        session_picker.show_sort_picker(function()
          M.list_all_files({ initial_mode = 'normal' }):find()
        end)
      end, { desc = 'configure sort' })

      map('n', 'S', function()
        actions.close(prompt_bufnr)
        vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path()))
      end, { desc = 'edit session config' })

      map('n', 'L', function()
        local _ = session.toggle_layout()
        actions.close(prompt_bufnr)
        M.list_all_files({ initial_mode = 'normal' }):find()
      end, { desc = 'toggle layout' })

      local picker_help = require('shooter.telescope.picker_help')
      map('n', '?', picker_help.show_shotfile_help, { desc = 'show keymaps' })
      map('i', '<C-/>', picker_help.show_shotfile_help, { desc = 'show keymaps' })

      map('n', '<C-n>', actions.move_selection_next, { desc = 'next result' })
      map('n', '<C-p>', actions.move_selection_previous, { desc = 'previous result' })
      map('i', '<C-n>', actions.move_selection_next, { desc = 'next result' })
      map('i', '<C-p>', actions.move_selection_previous, { desc = 'previous result' })

      map('n', '<C-c>', actions.close, { desc = 'close picker' })

      map('n', 'n', function() actions.close(prompt_bufnr); vim.cmd('HalShooterShotfileNew') end, { desc = 'new shotfile' })
      local movement = require('shooter.core.movement')
      local function move_to(folder)
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          if movement.move_file_path(entry.value.path, folder) then refresh_picker(prompt_bufnr) end
        end
      end

      local prefix = shooter_config.get('keymaps.prefix') or ' '
      map('n', prefix .. 'fma', function() move_to('archive') end, { desc = 'Move to archive' })
      map('n', prefix .. 'fmb', function() move_to('backlog') end, { desc = 'Move to backlog' })
      map('n', prefix .. 'fmd', function() move_to('done') end, { desc = 'Move to done' })
      map('n', prefix .. 'fmp', function() move_to('') end, { desc = 'Move to prompts' })
      map('n', prefix .. 'fmr', function() move_to('reqs') end, { desc = 'Move to reqs' })
      map('n', prefix .. 'fmt', function() move_to('test') end, { desc = 'Move to test' })
      map('n', prefix .. 'fmw', function() move_to('wait') end, { desc = 'Move to wait' })

      local function rename_selected()
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          local rename = require('shooter.core.rename')
          actions.close(prompt_bufnr)
          vim.cmd('edit ' .. vim.fn.fnameescape(entry.value.path))
          rename.rename_current_file()
        end
      end
      map('n', prefix .. 'fr', rename_selected, { desc = 'Rename file' })

      map('n', prefix .. 'fd', function()
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          local filepath = entry.value.path
          local filename = vim.fn.fnamemodify(filepath, ':t')
          vim.ui.input({ prompt = 'Delete ' .. filename .. '? (y/n): ' }, function(confirm)
            if confirm == 'y' then
              vim.fn.delete(filepath)
              refresh_picker(prompt_bufnr)
            end
          end)
        end
      end, { desc = 'Delete file' })

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          actions.close(prompt_bufnr)
          files_mod.open_shotfile(entry.value.path)
        else
          local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
          if not prompt or prompt == '' then return end
          actions.close(prompt_bufnr)
          local git_worktree = require('shooter.tools.git_worktree')
          local base = git_worktree.get_main_worktree() or files_mod.get_git_root() or utils.cwd()
          local shotfiles_dir = base .. '/docs/shotfiles'
          local dir_part, name_part = prompt:match('^(.+)/(.+)$')
          local target_dir, name
          if dir_part and name_part then
            local dir_slug = files_mod.slugify_path(dir_part)
            target_dir = shotfiles_dir .. (dir_slug ~= '' and ('/' .. dir_slug) or '')
            name = name_part
          else
            target_dir = shotfiles_dir
            name = prompt
          end
          vim.fn.mkdir(target_dir, 'p')
          local slug = files_mod.generate_filename(name):gsub('%.md$', '')
          if slug == '' then return end
          local filepath = target_dir .. '/' .. slug .. '.md'
          local path_title = files_mod.title_from_path(filepath)
          local content = string.format('# %s\n\n## shot 1 \n', path_title)
          local f = io.open(filepath, 'w')
          if f then
            f:write(content)
            f:close()
            files_mod.open_shotfile(filepath)
            vim.schedule(function()
              local lc = vim.api.nvim_buf_line_count(0)
              vim.api.nvim_win_set_cursor(0, {math.min(3, lc), 0})
              vim.cmd('startinsert!')
            end)
          end
        end
      end)

      return true
    end,
  })
  return picker_instance
end

function M.list_all_files(opts)
  opts = opts or {}
  local files_mod = require('shooter.core.files')

  local git_worktree = require('shooter.tools.git_worktree')
  local main_root = git_worktree.get_main_worktree() or files_mod.get_git_root()

  local get_files_fn = function()
    return helpers.get_prompt_files({ include_all_projects = true })
  end

  local home = os.getenv('HOME') or ''
  local repo_path = main_root and main_root:gsub('^' .. vim.pesc(home), '~') or 'Next Actions'
  return create_file_picker(opts, get_files_fn, repo_path, main_root)
end

function M.list_all_repos_files(opts)
  opts = opts or {}
  local get_files_fn = function()
    return helpers.get_all_repos_prompt_files({})
  end
  return create_file_picker(opts, get_files_fn, 'All Repos')
end

return M

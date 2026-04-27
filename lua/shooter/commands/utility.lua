-- Utility / Nav / Bullet command blocks (no main namespace prefix).

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd
local require_shotfile = util.require_shotfile

local M = {}

local function setup_utility_commands()
  create_cmd('HalShooterClearFilter', function()
    local filter_state = require('shooter.filter_state')
    filter_state.clear_all_filters()
  end, { desc = 'Clear all filters' })

  create_cmd('HalShooterInbox', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      return
    end
    local inbox_path = git_root .. '/INBOX.md'
    if vim.fn.filereadable(inbox_path) ~= 1 then
      local file = io.open(inbox_path, 'w')
      if file then file:write('# Inbox\n\n'); file:close() end
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(inbox_path))
  end, { desc = 'Open INBOX.md at git root' })

  create_cmd('HalShooterMetaplanOpen', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    metaplan.fix(git_root)
    vim.cmd('edit ' .. vim.fn.fnameescape(metaplan.get_path(git_root)))
  end, { desc = 'Open docs/plans/metaplan.md at git root (fix on open)' })

  -- HalShooterMetaplanFix — normalize, sync, commit (no push).
  create_cmd('HalShooterMetaplanFix', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    local ok, err = metaplan.fix(git_root)
    if not ok then
      utils.echo('metaplan fix failed: ' .. (err or ''))
      return
    end
    local cok, cmsg, committed = metaplan.commit_plans(git_root)
    if not cok then
      utils.echo('metaplan: fixed; commit failed: ' .. (cmsg or ''))
    elseif committed then
      utils.echo('metaplan: fixed + committed')
    else
      utils.echo('metaplan: fixed (' .. (cmsg or 'no changes to commit') .. ')')
    end
  end, { desc = 'Fix metaplan.md and commit docs/plans + plan shotfiles' })

  -- HalShooterMetaplanOpen{Plan,Context,Spec,Masterplan} — open the
  -- docs/plans/<plan>/<kind>.md file for the plan under cursor.
  local function open_plan_file(kind)
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local ok, msg = metaplan.open_plan_file(git_root, line, kind)
    if not ok then utils.echo('metaplan: ' .. (msg or 'unknown')) end
  end
  create_cmd('HalShooterMetaplanOpenPlan',       function() open_plan_file('plan')       end,
    { desc = 'Open docs/plans/<plan>/plan.md for plan under cursor' })
  create_cmd('HalShooterMetaplanOpenContext',    function() open_plan_file('context')    end,
    { desc = 'Open docs/plans/<plan>/context.md for plan under cursor' })
  create_cmd('HalShooterMetaplanOpenSpec',       function() open_plan_file('spec')       end,
    { desc = 'Open docs/plans/<plan>/spec.md for plan under cursor' })
  create_cmd('HalShooterMetaplanOpenMasterplan', function() open_plan_file('masterplan') end,
    { desc = 'Open docs/plans/<plan>/masterplan.md for plan under cursor' })

  create_cmd('HalShooterMetaplanMarkDone', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local ok, err = metaplan.mark_done(git_root, lnum)
    utils.echo(ok and 'metaplan: marked done' or ('metaplan mark done failed: ' .. (err or '')))
  end, { desc = 'Move plan under cursor to ## done with timestamp' })

  create_cmd('HalShooterGitPush', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local git_push = require('shooter.core.git_push')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    local ok, msg = git_push.run(git_root)
    utils.echo(msg or (ok and 'shotfiles: done' or 'git push failed'))
  end, { desc = 'git add/commit/push docs/shotfiles' })

  -- HalShooterShotfileMergeInto — pick target via telescope; merge + delete source.
  create_cmd('HalShooterShotfileMergeInto', require_shotfile(function()
    local source_path = vim.api.nvim_buf_get_name(0)
    if source_path == '' then
      require('shooter.utils').echo('no current file')
      return
    end

    local helpers = require('shooter.telescope.helpers')
    local tele_pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    local all = helpers.get_prompt_files({ include_all_projects = true })
    local candidates = {}
    for _, entry in ipairs(all) do
      if entry.path ~= source_path then table.insert(candidates, entry) end
    end
    if #candidates == 0 then
      require('shooter.utils').echo('no other shotfile to merge into')
      return
    end

    tele_pickers.new({}, {
      prompt_title = 'Merge into shotfile',
      layout_strategy = 'vertical',
      layout_config = { width = 0.8, height = 0.6 },
      finder = finders.new_table({
        results = candidates,
        entry_maker = function(e)
          return { value = e, display = e.display, ordinal = e.display, path = e.path }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry or not entry.value or not entry.value.path then return end
          local target_path = entry.value.path
          vim.ui.input({
            prompt = 'Merge into ' .. vim.fn.fnamemodify(target_path, ':t')
              .. '? (y/n): '
          }, function(confirm)
            if confirm == 'y' then
              local merge = require('shooter.core.shotfile_merge')
              local ok, msg = merge.merge_into(source_path, target_path)
              require('shooter.utils').echo(msg or (ok and 'merged' or 'merge failed'))
            end
          end)
        end)
        map('n', '<C-c>', actions.close, { desc = 'close' })
        map('n', 'q', actions.close, { desc = 'close' })
        return true
      end,
    }):find()
  end), { desc = 'Merge current shotfile into another (pick target)' })

  -- HalShooterOpenLinkPicker — link picker for current buffer.
  create_cmd('HalShooterOpenLinkPicker', function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local links = require('shooter.tools.links')
    local entries = links.collect_from_lines(lines, nil)
    table.sort(entries, function(a, b)
      if a.line == b.line then return a.col < b.col end
      return a.line < b.line
    end)
    require('shooter.telescope.link_picker').open(entries, {
      title = 'Links in ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t'),
    })
  end, { desc = 'Open link picker for current buffer' })

  -- HalShooterOpenLinkPickerTmux — link picker across tmux window panes.
  create_cmd('HalShooterOpenLinkPickerTmux', function()
    local tmux = require('shooter.tools.tmux_panes')
    if not tmux.in_tmux() then
      require('shooter.utils').echo('not inside a tmux session')
      return
    end
    local panes, err = tmux.list_current_window()
    if err or #panes == 0 then
      require('shooter.utils').echo(err or 'no tmux panes')
      return
    end
    local links = require('shooter.tools.links')
    local all = {}
    for _, pane in ipairs(panes) do
      local pane_lines = tmux.capture(pane.id)
      if pane_lines then
        local pane_entries = links.collect_from_lines(pane_lines, pane.title)
        for _, e in ipairs(pane_entries) do table.insert(all, e) end
      end
    end
    require('shooter.telescope.link_picker').open(all, {
      title = 'Links in tmux window',
      with_source = true,
    })
  end, { desc = 'Open link picker for tmux window panes' })

  create_cmd('HalShooterGitWorktreeOpenOil', function(opts)
    local number = tonumber(opts.args)
    if not number then
      require('shooter.utils').echo('usage: :HalShooterGitWorktreeOpenOil <number>')
      return
    end
    require('shooter.tools.git_worktree_oil').open_in_worktree(number)
  end, { nargs = 1, desc = 'Open oil at parallel folder in worktree <n>' })
end

local function setup_nav_commands()
  local files = require('shooter.core.files')

  -- Helper: find last N edited files in repo.
  local function get_last_edited_files(git_root, count)
    local cmd = string.format(
      'find "%s" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" ' ..
      '-not -path "*/__pycache__/*" -not -name "*.pyc" -not -name ".DS_Store" ' ..
      '-exec ls -t {} + 2>/dev/null | head -%d',
      git_root, count
    )
    local handle = io.popen(cmd)
    if not handle then return {} end
    local results = {}
    for line in handle:lines() do
      if line ~= '' then table.insert(results, line) end
    end
    handle:close()
    return results
  end

  create_cmd('HalShooterNavLastEditedFile', function()
    local git_root = files.get_cwd_git_root()
    if not git_root then
      return
    end
    local results = get_last_edited_files(git_root, 1)
    if #results > 0 then
      vim.cmd('edit ' .. vim.fn.fnameescape(results[1]))
    else
    end
  end, { desc = 'Open last edited file in repo' })

  create_cmd('HalShooterNavLastEditedFiles', function(opts)
    local git_root = files.get_cwd_git_root()
    if not git_root then
      return
    end
    local count = tonumber(opts.args) or 10
    local results = get_last_edited_files(git_root, count)
    if #results == 0 then
      return
    end

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = 'Last ' .. count .. ' Edited Files',
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          local short = entry:gsub('^' .. vim.pesc(git_root) .. '/', '')
          return { value = entry, display = short, ordinal = short }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        require('shooter.keymaps.picker').setup_nav_keymaps(map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then vim.cmd('edit ' .. vim.fn.fnameescape(selection.value)) end
        end)
        return true
      end,
    }):find()
  end, { nargs = '?', desc = 'Telescope picker for last N edited files' })
end

local function setup_bullet_commands()
  create_cmd('HalShooterBulletPickerCurrentFile', require_shotfile(function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_bullets_current_file()
    if picker then picker:find() end
  end), { desc = 'Bullet picker (current file)' })

  create_cmd('HalShooterBulletPickerCurrentRepo', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_bullets_current_repo()
    if picker then picker:find() end
  end, { desc = 'Bullet picker (current repo)' })

  create_cmd('HalShooterBulletPickerAllRepos', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_bullets_all_repos()
    if picker then picker:find() end
  end, { desc = 'Bullet picker (all repos)' })
end

M.setup_utility = setup_utility_commands
M.setup_nav = setup_nav_commands
M.setup_bullet = setup_bullet_commands

return M

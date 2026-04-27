-- Shotfile namespace commands (f prefix in keymaps).

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd
local require_shotfile = util.require_shotfile

local M = {}

function M.setup()
  local files = require('shooter.core.files')
  local movement = require('shooter.core.movement')
  local project_mod = require('shooter.core.project')

  -- HalShooterShotfileNew — create shotfile via Lua
  create_cmd('HalShooterShotfileNew', function(opts)
    local function create_with_title_and_project(title, project)
      if not title or title == '' then return end
      local path = files.create_file(title, '', '', project)
      if path then
        vim.cmd('edit! ' .. vim.fn.fnameescape(path))
        vim.schedule(function()
          local line_count = vim.api.nvim_buf_line_count(0)
          vim.api.nvim_win_set_cursor(0, {math.min(3, line_count), 0})
          vim.cmd('startinsert!')
        end)
      end
    end

    local function prompt_for_title(project)
      if opts.args ~= '' then
        create_with_title_and_project(opts.args, project)
      else
        vim.ui.input({ prompt = 'Feature title: ' }, function(title)
          create_with_title_and_project(title, project)
        end)
      end
    end

    local detected_project = project_mod.detect_from_cwd()
    if detected_project then
      prompt_for_title(detected_project)
    elseif project_mod.has_projects() then
      project_mod.pick_project(function(selected_project)
        prompt_for_title(selected_project)
      end, { include_root = true, title = 'Create in Project' })
    else
      prompt_for_title(nil)
    end
  end, { nargs = '?', desc = 'Create new shotfile' })

  create_cmd('HalShooterShotfileNewInRepo', function()
    require('shooter.core.repos').create_in_repo_picker()
  end, { desc = 'Create shotfile in any configured repo' })

  create_cmd('HalShooterShotfilePicker', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files({ include_all_projects = true })
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (current repo)' })

  create_cmd('HalShooterShotfilePickerAll', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_repos_files()
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (all repos)' })

  -- HalShooterShotfileLast — Neovim tracking first, hal CLI fallback.
  create_cmd('HalShooterShotfileLast', function()
    local last_file = files.get_last_edited_file()
    if not last_file then return end
    files.open_shotfile(last_file)
  end, { desc = 'Open last edited shotfile' })

  create_cmd('HalShooterShotfileRename', function()
    require('shooter.core.rename').rename_current_file()
  end, { desc = 'Rename current shotfile' })

  create_cmd('HalShooterShotfileDelete', function()
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == '' then
      return
    end
    vim.ui.input({ prompt = 'Delete ' .. vim.fn.fnamemodify(bufname, ':t') .. '? (y/n): ' }, function(confirm)
      if confirm == 'y' then
        vim.cmd('bdelete!')
        vim.fn.delete(bufname)
      end
    end)
  end, { desc = 'Delete current shotfile' })

  create_cmd('HalShooterShotfileOpenPrompts', function()
    local config = require('shooter.config')
    local prompts_dir = config.get('paths.prompts_dir')
    vim.fn.mkdir(prompts_dir, 'p')
    local created = files.ensure_theme_shotfiles()
    if created > 0 then
    end
    vim.cmd('Oil ' .. prompts_dir)
  end, { desc = 'Open Oil in prompts folder' })

  create_cmd('HalShooterOpenPlans', function()
    local files_local = require('shooter.core.files')
    local git_root = files_local.get_git_root()
    if git_root then
      local plans_dir = git_root .. '/plans'
      vim.fn.mkdir(plans_dir, 'p')
      vim.cmd('Oil ' .. plans_dir)
    else
    end
  end, { desc = 'Open plans folder in Oil' })

  create_cmd('HalShooterOpenShoConfig', function()
    local files_local = require('shooter.core.files')
    local git_root = files_local.get_git_root()
    if git_root then
      local shooter_dir = git_root .. '/.hal/util/shooter/config/nvim'
      vim.fn.mkdir(shooter_dir, 'p')
      vim.cmd('Oil ' .. shooter_dir)
    else
    end
  end, { desc = 'Open .hal/util/shooter/config/nvim folder in Oil' })

  -- Move commands
  create_cmd('HalShooterShotfileMoveArchive', movement.move_to_archive, { desc = 'Move to archive' })
  create_cmd('HalShooterShotfileMoveBacklog', movement.move_to_backlog, { desc = 'Move to backlog' })
  create_cmd('HalShooterShotfileMoveDone', movement.move_to_done, { desc = 'Move to done' })
  create_cmd('HalShooterShotfileMovePrompts', movement.move_to_prompts, { desc = 'Move to prompts' })
  create_cmd('HalShooterShotfileMoveReqs', movement.move_to_reqs, { desc = 'Move to reqs' })
  create_cmd('HalShooterShotfileMoveTest', movement.move_to_test, { desc = 'Move to test' })
  create_cmd('HalShooterShotfileMoveWait', movement.move_to_wait, { desc = 'Move to wait' })
  create_cmd('HalShooterShotfileMoveGitRoot', movement.move_to_git_root, { desc = 'Move to git root' })

  create_cmd('HalShooterShotfileMovePicker', function()
    require('shooter.core.move_picker').open_picker()
  end, { desc = 'Move file via fuzzy picker' })

  -- HalShooterFixAll — walk every shotfile and apply full cleanup
  create_cmd('HalShooterFixAll', function()
    local shotfile_fix = require('shooter.core.shotfile_fix')
    local ok, msg = shotfile_fix.run_all()
    require('shooter.utils').echo(msg or (ok and 'shotfiles fix: done' or 'shotfiles fix failed'))
  end, { desc = 'Fix all shotfiles in repo (title, empties, blanks, commit)' })

  -- HalShooterShotfileFix — cleanup current shotfile
  create_cmd('HalShooterShotfileFix', require_shotfile(function()
    local ok, msg = require('shooter.core.shotfile_fix').run()
    require('shooter.utils').echo(msg or (ok and 'shotfile fix: done' or 'shotfile fix failed'))
  end), { desc = 'Fix current shotfile: title, empty shots, renumber, commit' })
end

return M

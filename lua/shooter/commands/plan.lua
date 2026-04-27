-- Plan namespace commands (p prefix in keymaps).

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd

local M = {}

function M.setup()
  local files = require('shooter.core.files')
  local plan_picker = require('shooter.plans.picker')
  local utils = require('shooter.utils')

  local function open(basename)
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    plan_picker.open(git_root, basename)
  end

  create_cmd('HalShooterPlanPickerPlan',    function() open('plan')    end,
    { desc = 'Pick a docs/plans/**/plan.md file' })
  create_cmd('HalShooterPlanPickerContext', function() open('context') end,
    { desc = 'Pick a docs/plans/**/context.md file' })
  create_cmd('HalShooterPlanPickerSpec',    function() open('spec')    end,
    { desc = 'Pick a docs/plans/**/spec.md file' })

  create_cmd('HalShooterPlanPickerIdea', function()
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    plan_picker.open_ideas(git_root)
  end, { desc = 'Pick a docs/plans/<NNNN-slug>/idea.md' })

  create_cmd('HalShooterPlanOpenIdea', function()
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local ok, msg = metaplan.edit_plan_at_line(git_root, line)
    if not ok then
      utils.echo('PlanEdit: ' .. (msg or 'unknown'))
    else
      utils.echo('plan: ' .. msg)
    end
  end, { desc = 'Edit shotfile for plan under cursor (create/rename/open)' })

  create_cmd('HalShooterPlanNew', function(opts)
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local function create(title)
      if not title or title == '' then return end
      local ok, path_or_err = metaplan.new_plan(git_root, title)
      if not ok then
        utils.echo('PlanNew: ' .. (path_or_err or 'unknown'))
        return
      end
      vim.cmd('edit ' .. vim.fn.fnameescape(path_or_err))
    end
    if opts.args ~= '' then
      create(opts.args)
    else
      vim.ui.input({ prompt = 'Plan title: ' }, create)
    end
  end, { nargs = '?', desc = 'Create new plan under docs/plans/<NNNN-slug>/' })

  create_cmd('HalShooterPlanRename', function()
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local old_name = metaplan.extract_plan_name(line)
    if not old_name then
      utils.echo('PlanRename: cursor not on a plan line')
      return
    end
    vim.ui.input({ prompt = 'rename plan: ', default = old_name },
      function(new_name)
        if not new_name or new_name == '' then return end
        if new_name == old_name then return end
        local ok, msg = metaplan.rename_plan(git_root, old_name, new_name)
        utils.echo(ok and ('plan: ' .. msg) or ('PlanRename: ' .. (msg or 'unknown')))
      end)
  end, { desc = 'Rename plan under cursor (folder + shotfile + metaplan)' })

  -- HalShooterPlanDelete — three-tier preflight; on failure prompts for force.
  create_cmd('HalShooterPlanDelete', function()
    local metaplan = require('shooter.plans.metaplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local name = metaplan.extract_plan_name(line)
    if not name then
      utils.echo('PlanDelete: cursor not on a plan line')
      return
    end

    local function run(force)
      local ok, msg = metaplan.delete_plan(git_root, name,
        { folder = true, force = force })
      utils.echo(ok and ('plan: ' .. msg) or ('PlanDelete: ' .. (msg or 'unknown')))
    end

    local pre_ok, pre_reason = metaplan.delete_plan_preflight(git_root, name, false)
    if not pre_ok then
      vim.ui.input({
        prompt = 'cannot delete cleanly — ' .. pre_reason
          .. '. force delete? yes/no: ',
      }, function(ans) if ans == 'yes' then run(true) end end)
      return
    end
    vim.ui.input({ prompt = 'delete ' .. name .. '? yes/no: ' },
      function(ans) if ans == 'yes' then run(false) end end)
  end, { desc = 'Delete plan under cursor (cascade across worktrees; force on tier failure)' })
end

return M

-- Edit command registration for shooter.nvim (context files, config)

local M = {}

function M.setup()
  vim.api.nvim_create_user_command('ShooterEditGlobalContext', function()
    local config = require('shooter.config')
    local utils = require('shooter.utils')
    local global_path = utils.expand_path(config.get('paths.global_context'))
    vim.fn.mkdir(vim.fn.fnamemodify(global_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(global_path))
  end, { desc = 'Edit global shooter context file' })

  vim.api.nvim_create_user_command('ShooterEditProjectContext', function()
    local config = require('shooter.config')
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local project_path = git_root .. '/' .. config.get('paths.project_context')
    vim.fn.mkdir(vim.fn.fnamemodify(project_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(project_path))
  end, { desc = 'Edit project shooter context file' })

  vim.api.nvim_create_user_command('ShooterEditConfig', function()
    local utils = require('shooter.utils')
    local config_path = utils.find_config_file()
    if not config_path then
      vim.notify('Shooter config file not found. Check ~/.config/nvim/lua/plugins/', vim.log.levels.WARN)
      return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
  end, { desc = 'Edit shooter.nvim config file' })
end

return M

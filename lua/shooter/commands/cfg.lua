-- Cfg namespace commands (c prefix) + Hal<Domain>Config{Show,Edit} + HalConfigPicker.

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd

local M = {}

local function setup_cfg_commands()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  create_cmd('HalShooterCfgGlobal', function()
    local global_path = utils.expand_path(config.get('paths.global_context'))
    vim.fn.mkdir(vim.fn.fnamemodify(global_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(global_path))
  end, { desc = 'Edit global context' })

  create_cmd('HalShooterCfgProject', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      return
    end
    local project_path = git_root .. '/' .. config.get('paths.project_context')
    vim.fn.mkdir(vim.fn.fnamemodify(project_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(project_path))
  end, { desc = 'Edit project context' })

  create_cmd('HalShooterCfgPlugin', function()
    local config_path = utils.find_config_file()
    if not config_path then
      return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
  end, { desc = 'Edit plugin config' })

  create_cmd('HalShooterCfgShot', function()
    local session = require('shooter.session')
    local current = session.get_current_session()
    local modes = { 'normal', 'insert' }
    local current_mode = current.vimMode and current.vimMode.shotPicker or 'normal'
    local next_idx = 1
    for i, m in ipairs(modes) do
      if m == current_mode then next_idx = (i % #modes) + 1 end
    end
    session.set_vim_mode('shotPicker', modes[next_idx])
  end, { desc = 'Toggle shot picker vim mode' })

  create_cmd('HalShooterCfgReload', function()
    local ext_config = require('shooter.core.ext_config')
    ext_config.reload()
    require('shooter.syntax').reapply_all()
  end, { desc = 'Reload YAML config and reapply' })

  create_cmd('HalShooterCfgEditGlobal', function()
    local ext_config = require('shooter.core.ext_config')
    ext_config.ensure_global_config()
    vim.cmd('edit ' .. vim.fn.fnameescape(ext_config.global_config_path()))
  end, { desc = 'Edit global YAML config' })

  create_cmd('HalShooterCfgEditLocal', function()
    local ext_config = require('shooter.core.ext_config')
    local path = ext_config.ensure_local_config()
    if path then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    else
    end
  end, { desc = 'Edit project-local YAML config' })

  create_cmd('HalShooterCfgFix', function()
    local ext_config = require('shooter.core.ext_config')
    local bufpath = vim.api.nvim_buf_get_name(0)
    local is_global = bufpath:match('hal/util/shooter/nvim/config%.yaml$')
    local is_local = bufpath:match('%.hal/util/shooter/cfg/nvim/config%.yaml$')
    if not is_global and not is_local then
      return
    end
    local removed, added = ext_config.fix_config_buffer(0, is_global)
    local parts = {}
    if removed > 0 then table.insert(parts, 'removed ' .. removed .. ' invalid') end
    if added > 0 then table.insert(parts, 'added ' .. added .. ' missing') end
    if #parts == 0 then table.insert(parts, 'config OK') end
  end, { desc = 'Fix config: strip invalid keys, fill missing defaults' })

  create_cmd('HalShooterCfgShotfile', function()
    local session = require('shooter.session')
    vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path()))
  end, { desc = 'Edit shotfile picker session config' })
end

local function setup_hal_config_commands()
  local domains = {
    { name = 'Agent',    dir = 'agent' },
    { name = 'Api',      dir = 'api' },
    { name = 'Compose',  dir = 'docker-compose' },
    { name = 'Daemon',   dir = 'daemon' },
    { name = 'Env',      dir = 'env' },
    { name = 'Mcp',      dir = 'mcp' },
    { name = 'Port',     dir = 'port' },
    { name = 'Repo',     dir = 'repo' },
    { name = 'Server',   dir = 'server' },
    { name = 'Shooter',  dir = 'shooter' },
    { name = 'Smug',     dir = 'smug' },
    { name = 'Sync',     dir = 'sync' },
    { name = 'Template', dir = 'template' },
    { name = 'Youtube',  dir = 'youtube' },
  }

  local home = vim.fn.expand('~')

  for _, domain in ipairs(domains) do
    local config_path = home .. '/.config/hal/' .. domain.dir .. '/config.yml'

    create_cmd('Hal' .. domain.name .. 'ConfigShow', function()
      if vim.fn.filereadable(config_path) ~= 1 then
        return
      end
      vim.cmd('split ' .. vim.fn.fnameescape(config_path))
      vim.bo.readonly = true
      vim.bo.modifiable = false
    end, { desc = 'Show hal ' .. domain.dir .. ' config' })

    create_cmd('Hal' .. domain.name .. 'ConfigEdit', function()
      local dir = vim.fn.fnamemodify(config_path, ':h')
      vim.fn.mkdir(dir, 'p')
      if vim.fn.filereadable(config_path) ~= 1 then
        local file = io.open(config_path, 'w')
        if file then
          file:write('# hal config — see https://github.com/divramod/hal\n')
          file:close()
        end
      end
      vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
    end, { desc = 'Edit hal ' .. domain.dir .. ' config' })
  end
end

local function setup_hal_config_picker()
  create_cmd('HalConfigPicker', function()
    local home = vim.fn.expand('~')
    local hal_dir = home .. '/.config/hal'

    local handle = io.popen(string.format('find "%s" -name "*.yml" -type f 2>/dev/null | sort', hal_dir))
    if not handle then
      vim.notify('Could not scan ' .. hal_dir, vim.log.levels.WARN)
      return
    end
    local results = {}
    for line in handle:lines() do
      if line ~= '' then table.insert(results, line) end
    end
    handle:close()

    if #results == 0 then
      vim.notify('No .yml files found in ' .. hal_dir, vim.log.levels.INFO)
      return
    end

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    local previewers = require('telescope.previewers')

    pickers.new({}, {
      prompt_title = 'Hal Config (~/.config/hal)',
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          local short = entry:gsub('^' .. vim.pesc(hal_dir) .. '/', '')
          return { value = entry, display = short, ordinal = short }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        title = 'Config Preview',
        define_preview = function(self, entry)
          conf.buffer_previewer_maker(entry.value, self.state.bufnr, {
            bufname = self.state.bufname,
          })
        end,
      }),
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
  end, { desc = 'Pick hal config file (~/.config/hal)' })
end

function M.setup()
  setup_cfg_commands()
  setup_hal_config_commands()
  setup_hal_config_picker()
end

return M

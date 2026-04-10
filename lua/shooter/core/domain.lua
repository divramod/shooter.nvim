-- Domain management for shooter.nvim
-- Domains are user-created subfolders in .hal/shooter/shotfiles/

local utils = require('shooter.utils')

local M = {}

-- System folders that are NOT domains
local SYSTEM_FOLDERS = { 'archive', 'backlog', 'done', 'reqs', 'wait' }

local function is_system_folder(name)
  for _, f in ipairs(SYSTEM_FOLDERS) do
    if name == f then return true end
  end
  return false
end

local SHOTFILES_REL = '.hal/shooter/shotfiles'

-- Get the shotfiles root directory (absolute path)
local function get_shotfiles_dir()
  local files = require('shooter.core.files')
  local git_worktree = require('shooter.tools.git_worktree')
  local git_root = git_worktree.get_main_worktree() or files.get_git_root() or utils.cwd()
  return git_root .. '/' .. SHOTFILES_REL
end

-- List all domains (subdirectories that aren't system folders)
-- Returns: array of { name = string, path = string }
function M.list_domains()
  local shotfiles_dir = get_shotfiles_dir()
  if not utils.dir_exists(shotfiles_dir) then return {} end

  local entries = vim.fn.readdir(shotfiles_dir)
  local domains = {}
  for _, entry in ipairs(entries) do
    local full_path = shotfiles_dir .. '/' .. entry
    if vim.fn.isdirectory(full_path) == 1 and not is_system_folder(entry) then
      table.insert(domains, { name = entry, path = full_path })
    end
  end
  table.sort(domains, function(a, b) return a.name < b.name end)
  return domains
end

-- Create a new domain (subfolder)
-- Returns: path on success, nil on failure
function M.create_domain(name)
  if not name or name == '' then return nil end

  -- Sanitize: lowercase, replace spaces with dashes, strip non-alnum
  local slug = name:lower():gsub('%s+', '-'):gsub('[^%w%-]', ''):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
  if slug == '' then
    vim.notify('Invalid domain name', vim.log.levels.WARN)
    return nil
  end

  if is_system_folder(slug) then
    vim.notify('Cannot use system folder name as domain: ' .. slug, vim.log.levels.WARN)
    return nil
  end

  local shotfiles_dir = get_shotfiles_dir()
  local domain_path = shotfiles_dir .. '/' .. slug
  if vim.fn.isdirectory(domain_path) == 1 then
    vim.notify('Domain already exists: ' .. slug, vim.log.levels.INFO)
    return domain_path
  end

  vim.fn.mkdir(domain_path, 'p')
  vim.notify('Created domain: ' .. slug, vim.log.levels.INFO)
  return domain_path
end

-- Telescope picker to select a domain and move the current shotfile there
function M.pick_and_move()
  local files = require('shooter.core.files')
  local file_path = files.get_current_file_path()
  if not file_path or not files.is_in_prompts_folder(file_path) then
    vim.notify('Not in a shotfile', vim.log.levels.WARN)
    return
  end

  local domains = M.list_domains()
  if #domains == 0 then
    vim.notify('No domains found. Create one with :HalShooterDomainNew', vim.log.levels.WARN)
    return
  end

  local ok, _ = pcall(require, 'telescope')
  if not ok then
    vim.notify('Telescope is required for domain picker', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Move to Domain',
    finder = finders.new_table({
      results = domains,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection then
          -- Existing domain selected
          actions.close(prompt_bufnr)
          vim.cmd('silent! write')
          local old_bufnr = vim.fn.bufnr(file_path)
          local movement = require('shooter.core.movement')
          if movement.move_file_path(file_path, selection.value.name) then
            if old_bufnr ~= -1 then
              vim.api.nvim_buf_delete(old_bufnr, { force = true })
            end
            local filename = vim.fn.fnamemodify(file_path, ':t')
            local target = selection.value.path .. '/' .. filename
            vim.cmd('edit ' .. vim.fn.fnameescape(target))
          end
        else
          -- No match — parse prompt for domain/newname pattern
          local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
          if not prompt or prompt == '' then return end
          actions.close(prompt_bufnr)
          local shotfiles_dir = get_shotfiles_dir()
          local domain_part, name_part = prompt:match('^(.+)/(.+)$')
          local target_domain = domain_part or prompt
          -- Create domain if needed
          local domain_path = shotfiles_dir .. '/' .. target_domain
          vim.fn.mkdir(domain_path, 'p')
          -- Determine target filename
          local old_filename = vim.fn.fnamemodify(file_path, ':t')
          local new_filename = old_filename
          if name_part and name_part ~= '' then
            local slug = name_part:lower():gsub('%s+', '-'):gsub('[^%w%-]', ''):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
            if slug ~= '' then
              new_filename = slug .. '.md'
            end
          end
          local target_path = domain_path .. '/' .. new_filename
          if utils.file_exists(target_path) then
            vim.notify('Target already exists: ' .. target_domain .. '/' .. new_filename, vim.log.levels.WARN)
            return
          end
          -- Save buffer before moving to ensure disk is up to date
          vim.cmd('silent! write')
          local old_bufnr = vim.fn.bufnr(file_path)
          local success = os.rename(file_path, target_path)
          if success then
            -- Delete the old buffer (file no longer exists at old path)
            if old_bufnr ~= -1 then
              vim.api.nvim_buf_delete(old_bufnr, { force = true })
            end
            vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
            -- Update title if renamed
            if new_filename ~= old_filename and name_part then
              local bufnr = vim.api.nvim_get_current_buf()
              local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
              if first_line:match('^# ') then
                vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { '# ' .. name_part })
                vim.cmd('silent! write')
              end
            end
            vim.notify('Moved to ' .. target_domain .. '/' .. new_filename, vim.log.levels.INFO)
          end
        end
      end)
      return true
    end,
  }):find()
end

-- Rename a domain: pick domain, prompt for new name, rename dir, update open buffers
function M.rename()
  local domains = M.list_domains()
  if #domains == 0 then
    vim.notify('No domains found', vim.log.levels.WARN)
    return
  end

  local ok, _ = pcall(require, 'telescope')
  if not ok then
    vim.notify('Telescope is required for domain picker', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Rename Domain',
    finder = finders.new_table({
      results = domains,
      entry_maker = function(entry)
        return { value = entry, display = entry.name, ordinal = entry.name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if not selection then return end
        local old = selection.value
        vim.ui.input({ prompt = 'New name for ' .. old.name .. ': ', default = old.name }, function(new_name)
          if not new_name or new_name == '' or new_name == old.name then return end
          local slug = new_name:lower():gsub('%s+', '-'):gsub('[^%w%-]', ''):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
          if slug == '' or is_system_folder(slug) then
            vim.notify('Invalid domain name', vim.log.levels.WARN)
            return
          end
          local shotfiles_dir = get_shotfiles_dir()
          local new_path = shotfiles_dir .. '/' .. slug
          if vim.fn.isdirectory(new_path) == 1 then
            vim.notify('Domain already exists: ' .. slug, vim.log.levels.WARN)
            return
          end
          local success = os.rename(old.path, new_path)
          if not success then
            vim.notify('Failed to rename domain', vim.log.levels.ERROR)
            return
          end
          -- Update all open buffers that were in the old domain
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
              local bufname = vim.api.nvim_buf_get_name(buf)
              if bufname:find(old.path, 1, true) then
                local new_bufname = bufname:gsub(vim.pesc(old.path), new_path, 1)
                vim.api.nvim_buf_set_name(buf, new_bufname)
                vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end)
              end
            end
          end
          vim.notify('Renamed domain: ' .. old.name .. ' -> ' .. slug, vim.log.levels.INFO)
        end)
      end)
      return true
    end,
  }):find()
end

return M

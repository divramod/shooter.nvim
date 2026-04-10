-- Domain management for shooter.nvim
-- Domains are user-created subfolders in .hal/shooter/shotfiles/

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- System folders that are NOT domains
local SYSTEM_FOLDERS = { 'archive', 'backlog', 'done', 'reqs', 'wait', 'test' }

local function is_system_folder(name)
  for _, f in ipairs(SYSTEM_FOLDERS) do
    if name == f then return true end
  end
  return false
end

-- Get the shotfiles root directory (absolute path)
local function get_shotfiles_dir()
  local files = require('shooter.core.files')
  local git_worktree = require('shooter.tools.git_worktree')
  local git_root = git_worktree.get_main_worktree() or files.get_git_root() or utils.cwd()
  return git_root .. '/' .. config.get('paths.prompts_root')
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
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          local movement = require('shooter.core.movement')
          movement.move_file_path(file_path, selection.value.name)
        end
      end)
      return true
    end,
  }):find()
end

return M

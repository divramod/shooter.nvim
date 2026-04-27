-- Bullet-file walker. Pure Lua + filesystem; no telescope dependency.
local M = {}

local utils = require('shooter.utils')
local io_mod = require('shooter.telescope.helpers.io')

-- opts:
--   scope: 'file' (current shotfile), 'repo' (current repo), 'all' (all repos)
--   shotfile_basename: filter by shotfile name (for scope='file')
--   repo_slug: filter by repo name (for scope='repo')
function M.get_bullet_files(opts)
  opts = opts or {}
  local ext_config = require('shooter.core.ext_config')
  local bullets_root = ext_config.bullets_dir()
  local results = {}

  if not utils.dir_exists(bullets_root) then return results end

  local function add_bullets_from_dir(dir, repo_name)
    if not utils.dir_exists(dir) then return end
    local files = vim.fn.globpath(dir, '*.md', false, true)
    for _, filepath in ipairs(files) do
      local filename = vim.fn.fnamemodify(filepath, ':t')
      local display = repo_name and (repo_name .. '/' .. filename) or filename
      table.insert(results, {
        display = display,
        path = filepath,
        repo = repo_name,
        _mtime = io_mod.get_file_mtime(filepath),
      })
    end
  end

  if opts.scope == 'file' then
    local repo_slug = opts.repo_slug
    local basename = opts.shotfile_basename
    if not repo_slug or not basename then return results end
    local dir = bullets_root .. '/' .. repo_slug
    if not utils.dir_exists(dir) then return results end
    local files = vim.fn.globpath(dir, basename .. '_*.md', false, true)
    for _, filepath in ipairs(files) do
      local filename = vim.fn.fnamemodify(filepath, ':t')
      table.insert(results, {
        display = filename,
        path = filepath,
        repo = repo_slug,
        _mtime = io_mod.get_file_mtime(filepath),
      })
    end
  elseif opts.scope == 'repo' then
    local repo_slug = opts.repo_slug
    if not repo_slug then return results end
    add_bullets_from_dir(bullets_root .. '/' .. repo_slug, nil)
  else
    if vim.fn.isdirectory(bullets_root) == 1 then
      for _, repo_name in ipairs(vim.fn.readdir(bullets_root)) do
        local repo_dir = bullets_root .. '/' .. repo_name
        if vim.fn.isdirectory(repo_dir) == 1 then
          add_bullets_from_dir(repo_dir, repo_name)
        end
      end
    end
  end

  table.sort(results, function(a, b)
    return (a._mtime or 0) > (b._mtime or 0)
  end)

  return results
end

return M

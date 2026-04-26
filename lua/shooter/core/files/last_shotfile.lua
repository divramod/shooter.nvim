-- Last-shotfile tracking. In-memory + persisted to ext_config's last_shotfile_path.
-- Reading: find_last_file (primary: in-memory; secondary: persisted; tertiary: ls -t).
-- Writing: track_last_shotfile (called from syntax.lua's BufEnter hook).

local utils = require('shooter.utils')
local git = require('shooter.core.files.git')
local predicate = require('shooter.core.files.predicate')
local path_mod = require('shooter.core.files.path')

local M = {}

local _last_shotfile = nil

local function _last_shotfile_path_for_main()
  local git_root = git.get_git_root()
  if not git_root then return nil end
  local storage = require('shooter.session.storage')
  local ext_config = require('shooter.core.ext_config')
  local slug = storage.get_repo_slug(git_root)
  return ext_config.last_shotfile_path(slug:gsub('/', '_'))
end

local function _persist_last_shotfile(filepath)
  local path = _last_shotfile_path_for_main()
  if not path then return end
  utils.ensure_dir(utils.get_dirname(path))
  local f = io.open(path, 'w')
  if f then f:write(filepath); f:close() end
end

local function _load_last_shotfile()
  local path = _last_shotfile_path_for_main()
  if not path then return nil end
  local f = io.open(path, 'r')
  if f then
    local content = f:read('*l'); f:close()
    if content and vim.fn.filereadable(content) == 1
        and predicate.is_last_trackable(content) then
      return content
    end
  end
  return nil
end

function M.track_last_shotfile(filepath)
  if not predicate.is_last_trackable(filepath) then return end
  _last_shotfile = filepath
  _persist_last_shotfile(filepath)
end

function M.find_last_file(project)
  if _last_shotfile and vim.fn.filereadable(_last_shotfile) == 1
      and predicate.is_last_trackable(_last_shotfile) then
    return _last_shotfile
  end

  local persisted = _load_last_shotfile()
  if persisted then
    _last_shotfile = persisted
    return persisted
  end

  local prompts_dir = path_mod.get_prompts_dir(project)

  if not utils.dir_exists(prompts_dir) then
    return nil
  end

  local cmd = string.format('find "%s" -name "*.md" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1', prompts_dir)
  local result = utils.system(cmd)

  if not result or result == '' then
    return nil
  end

  return result:gsub('%s+$', '')
end

function M.get_last_edited_file(project)
  return M.find_last_file(project)
end

return M

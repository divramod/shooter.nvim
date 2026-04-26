-- Path + title helpers for shooter shotfiles.
-- Slugify, generate filename, title↔path bridging, current-file/oil probes.

local utils = require('shooter.utils')

local M = {}

function M.get_current_file_path()
  local filetype = vim.bo.filetype

  if filetype == 'oil' then
    local ok, oil = pcall(require, 'oil')
    if ok then
      local entry = oil.get_cursor_entry()
      if entry and entry.type == 'file' then
        local dir = oil.get_current_dir()
        return dir .. entry.name
      end
    end
    return nil
  else
    return vim.fn.expand('%:p')
  end
end

function M.get_current_file_or_folder_path()
  local filetype = vim.bo.filetype

  if filetype == 'oil' then
    local ok, oil = pcall(require, 'oil')
    if ok then
      local entry = oil.get_cursor_entry()
      if entry then
        local dir = oil.get_current_dir()
        return dir .. entry.name, entry.type
      end
    end
    return nil, nil
  else
    return vim.fn.expand('%:p'), 'file'
  end
end

function M.get_prompts_dir(project)
  local project_mod = require('shooter.core.project')
  return project_mod.get_prompts_dir(project)
end

-- Slugify a single path segment (lowercase, non-alnum stripped, dedup -, trim).
function M.slugify_segment(segment)
  if not segment or segment == '' then return '' end
  local slug = segment:lower()
  slug = slug:gsub('%s+', '-')
  slug = slug:gsub('[^%w%-]', '')
  slug = slug:gsub('%-+', '-')
  slug = slug:gsub('^%-', ''):gsub('%-$', '')
  return slug
end

-- Slugify every segment of a slash-separated path. Preserves an empty
-- trailing segment so "foo bar/" stays "foo-bar/".
function M.slugify_path(path)
  if not path or path == '' then return '' end
  local trailing = path:sub(-1) == '/'
  local parts = {}
  for seg in path:gmatch('[^/]+') do
    table.insert(parts, M.slugify_segment(seg))
  end
  local out = table.concat(parts, '/')
  if trailing then out = out .. '/' end
  return out
end

function M.generate_filename(title)
  return string.format('%s.md', M.slugify_segment(title))
end

-- Compute title from file path (relative path from shotfiles root, without .md).
function M.title_from_path(filepath)
  local match = filepath:match('/docs/shotfiles/(.+)$')
  if match then
    return match:gsub('%.md$', '')
  end
  local plan_match = filepath:match('/(docs/plans/[^/]+/[^/]+)$')
  if plan_match then
    return plan_match:gsub('%.md$', '')
  end
  return vim.fn.fnamemodify(filepath, ':t:r')
end

-- Update the # title heading in a file on disk. Returns true on rewrite.
function M.update_file_title(filepath, new_title)
  local content = utils.read_file(filepath)
  if not content then return false end
  local safe_title = new_title:gsub('%%', '%%%%')
  local updated = content:gsub('^(#[ \t]+)[^\n]+', '%1' .. safe_title, 1)
  if updated == content then
    updated = content:gsub('\n(#[ \t]+)[^\n]+', '\n%1' .. safe_title, 1)
  end
  if updated ~= content then
    utils.write_file(filepath, updated)
    return true
  end
  return false
end

return M

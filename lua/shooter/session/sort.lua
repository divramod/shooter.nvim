-- Session sort - Multi-criteria sorting with priorities
-- Supports stacking multiple sort criteria

local M = {}

-- Cache for file metadata
local metadata_cache = {}

-- Clear metadata cache (call when files change)
function M.clear_cache()
  metadata_cache = {}
end

-- Get file metadata (mtime, ctime, shotcount)
---@param filepath string Full file path
---@return table Metadata {mtime, ctime, shotcount, filename, path}
function M.get_file_metadata(filepath)
  if metadata_cache[filepath] then
    return metadata_cache[filepath]
  end

  local stat = vim.loop.fs_stat(filepath)
  local mtime = stat and stat.mtime.sec or 0
  local ctime = stat and stat.ctime.sec or 0

  -- Extract filename without extension
  local filename = filepath:match('([^/]+)%.md$') or filepath:match('([^/]+)$') or ''

  -- Count open shots in file
  local shotcount = 0
  local file = io.open(filepath, 'r')
  if file then
    local content = file:read('*a')
    file:close()
    for _ in content:gmatch('\n##%s+shot%s') do
      shotcount = shotcount + 1
    end
  end

  -- Extract project name from path
  local projectname = filepath:match('/projects/([^/]+)/') or ''

  metadata_cache[filepath] = {
    mtime = mtime,
    ctime = ctime,
    shotcount = shotcount,
    filename = filename,
    path = filepath,
    projectname = projectname,
  }

  return metadata_cache[filepath]
end

-- Get enabled sort criteria sorted by priority
---@param sort_config table Sort configuration from session
---@return table[] Array of {name, ascending} sorted by priority
function M.get_enabled_criteria(sort_config)
  local criteria = {}
  for name, cfg in pairs(sort_config) do
    if cfg.enabled and cfg.priority and cfg.priority > 0 then
      table.insert(criteria, {
        name = name,
        priority = cfg.priority,
        ascending = cfg.ascending,
      })
    end
  end
  -- Sort by priority (lower number = higher priority)
  table.sort(criteria, function(a, b)
    return a.priority < b.priority
  end)
  return criteria
end

-- Single criterion comparator
---@param name string Criterion name
---@param ascending boolean Sort direction
---@return function Comparator function
local function make_comparator(name, ascending)
  return function(a, b)
    local meta_a = M.get_file_metadata(a.path)
    local meta_b = M.get_file_metadata(b.path)

    local val_a, val_b

    if name == 'filename' then
      val_a, val_b = meta_a.filename:lower(), meta_b.filename:lower()
    elseif name == 'modified' then
      val_a, val_b = meta_a.mtime, meta_b.mtime
    elseif name == 'created' then
      val_a, val_b = meta_a.ctime, meta_b.ctime
    elseif name == 'shotcount' then
      val_a, val_b = meta_a.shotcount, meta_b.shotcount
    elseif name == 'projectname' then
      val_a, val_b = meta_a.projectname:lower(), meta_b.projectname:lower()
    elseif name == 'path' then
      val_a, val_b = a.path:lower(), b.path:lower()
    else
      return nil -- Unknown criterion
    end

    if val_a == val_b then
      return nil -- Equal, check next criterion
    end

    if ascending then
      return val_a < val_b
    else
      return val_a > val_b
    end
  end
end

-- Build multi-criteria comparator
---@param criteria table[] Array of {name, ascending}
---@return function Comparator function
function M.build_comparator(criteria)
  local comparators = {}
  for _, c in ipairs(criteria) do
    table.insert(comparators, make_comparator(c.name, c.ascending))
  end

  return function(a, b)
    for _, cmp in ipairs(comparators) do
      local result = cmp(a, b)
      if result ~= nil then
        return result
      end
    end
    -- All criteria equal, maintain original order
    return false
  end
end

-- Sort files according to session sortBy configuration
---@param files table[] Array of file entries
---@param session table Session object
---@return table[] Sorted files
function M.sort_files(files, session)
  if not session or not session.sortBy then
    return files
  end

  local criteria = M.get_enabled_criteria(session.sortBy)
  if #criteria == 0 then
    return files
  end

  local comparator = M.build_comparator(criteria)
  table.sort(files, comparator)
  return files
end

-- Get sort status string for display
---@param session table Session object
---@return string Status string (e.g., "filename, modified desc")
function M.get_sort_status(session)
  if not session or not session.sortBy then
    return 'default'
  end

  local criteria = M.get_enabled_criteria(session.sortBy)
  if #criteria == 0 then
    return 'default'
  end

  local parts = {}
  for _, c in ipairs(criteria) do
    local dir = c.ascending and '' or ' desc'
    table.insert(parts, c.name .. dir)
  end
  return table.concat(parts, ', ')
end

return M

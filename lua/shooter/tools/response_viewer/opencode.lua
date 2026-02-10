-- OpenCode response lookup for shooter.nvim
local utils = require('shooter.utils')

local M = {}

local function get_storage_paths()
  local data_home = os.getenv('XDG_DATA_HOME')
  if not data_home or data_home == '' then
    data_home = utils.expand_path('~/.local/share')
  end
  local storage = data_home .. '/opencode/storage'
  return {
    message_dir = storage .. '/message',
    part_dir = storage .. '/part',
  }
end

local function read_json(path)
  local content = utils.read_file(path)
  if not content then return nil end
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok then return nil end
  return data
end

local function list_session_dirs(message_dir)
  if not utils.dir_exists(message_dir) then return {} end
  local dirs = vim.fn.glob(message_dir .. '/*', false, true)
  local result = {}
  for _, path in ipairs(dirs) do
    if vim.fn.isdirectory(path) == 1 then
      table.insert(result, path)
    end
  end
  table.sort(result, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  return result
end

local function read_messages(session_dir)
  local files = vim.fn.glob(session_dir .. '/*.json', false, true)
  local entries = {}
  for _, path in ipairs(files) do
    local data = read_json(path)
    if data then table.insert(entries, data) end
  end
  table.sort(entries, function(a, b)
    local a_time = a.time and a.time.created or 0
    local b_time = b.time and b.time.created or 0
    if a_time ~= b_time then return a_time < b_time end
    return (a.id or '') < (b.id or '')
  end)
  return entries
end

local function read_parts(part_dir, message_id)
  local dir = part_dir .. '/' .. message_id
  if not utils.dir_exists(dir) then return {} end
  local files = vim.fn.glob(dir .. '/*.json', false, true)
  local parts = {}
  for _, path in ipairs(files) do
    local data = read_json(path)
    if data then table.insert(parts, data) end
  end
  table.sort(parts, function(a, b)
    local a_time = a.time and a.time.start or 0
    local b_time = b.time and b.time.start or 0
    if a_time ~= b_time then return a_time < b_time end
    return (a.id or '') < (b.id or '')
  end)
  return parts
end

local function message_matches_pattern(parts, shot_pattern)
  for _, part in ipairs(parts) do
    if part.type == 'text' and part.text and part.text:match(shot_pattern) then
      return true
    end
  end
  return false
end

local function build_related_set(entries, root_id)
  local related = { [root_id] = true }
  for _ = 1, 20 do
    local added = false
    for _, entry in ipairs(entries) do
      local parent = entry.parentID
      if parent and related[parent] and entry.id and not related[entry.id] then
        related[entry.id] = true
        added = true
      end
    end
    if not added then break end
  end
  return related
end

local function collect_response(entries, related, get_parts)
  local response_text = nil
  local tool_calls = {}
  for _, entry in ipairs(entries) do
    if entry.id and related[entry.id] and entry.role == 'assistant' then
      local parts = get_parts(entry.id)
      for _, part in ipairs(parts) do
        if part.type == 'text' and part.text then
          response_text = (response_text or '') .. part.text .. '\n'
        elseif (part.type == 'tool' or part.type == 'tool_use') and (part.tool or part.name) then
          table.insert(tool_calls, part.tool or part.name)
        end
      end
    end
  end
  return response_text, tool_calls
end

function M.find_response(shot_pattern)
  local paths = get_storage_paths()
  local sessions = list_session_dirs(paths.message_dir)
  if #sessions == 0 then return nil, {} end

  for _, session_dir in ipairs(sessions) do
    local entries = read_messages(session_dir)
    local parts_cache = {}
    local function get_parts(message_id)
      if not parts_cache[message_id] then
        parts_cache[message_id] = read_parts(paths.part_dir, message_id)
      end
      return parts_cache[message_id]
    end

    local user_id = nil
    for _, entry in ipairs(entries) do
      if entry.role == 'user' and entry.id then
        if message_matches_pattern(get_parts(entry.id), shot_pattern) then
          user_id = entry.id
          break
        end
      end
    end

    if user_id then
      local related = build_related_set(entries, user_id)
      local response_text, tool_calls = collect_response(entries, related, get_parts)
      if response_text or #tool_calls > 0 then
        return response_text, tool_calls
      end
    end
  end

  return nil, {}
end

return M

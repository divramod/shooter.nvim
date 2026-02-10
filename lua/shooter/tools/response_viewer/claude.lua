-- Claude response lookup for shooter.nvim
local utils = require('shooter.utils')

local M = {}

-- Get Claude projects directory for current repo
-- Claude escapes: / -> -, . -> - (keeps leading dash)
local function get_projects_dir()
  local cwd = vim.fn.getcwd()
  local escaped = cwd:gsub('/', '-'):gsub('%.', '-')
  return utils.expand_path('~/.claude/projects/' .. escaped)
end

-- Find assistant response by tracking parentUuid chain from user message
local function find_response_in_jsonl(jsonl_path, shot_pattern)
  local file = io.open(jsonl_path, 'r')
  if not file then return nil, {} end

  local user_uuid = nil
  local entries = {}
  for line in file:lines() do
    local ok, data = pcall(vim.fn.json_decode, line)
    if ok and data then
      table.insert(entries, data)
      if not user_uuid and data.type == 'user' and data.message and data.message.content then
        local content = data.message.content
        local content_str = type(content) == 'string' and content or vim.fn.json_encode(content)
        if content_str:match(shot_pattern) then
          user_uuid = data.uuid
        end
      end
    end
  end
  file:close()
  if not user_uuid then return nil, {} end

  local related = { [user_uuid] = true }
  for _ = 1, 20 do
    local added = false
    for _, entry in ipairs(entries) do
      if entry.parentUuid
          and type(entry.parentUuid) == 'string'
          and related[entry.parentUuid]
          and entry.uuid
          and type(entry.uuid) == 'string'
          and not related[entry.uuid] then
        related[entry.uuid] = true
        added = true
      end
    end
    if not added then break end
  end

  local response_text = nil
  local tool_calls = {}
  for _, entry in ipairs(entries) do
    if entry.uuid and type(entry.uuid) == 'string' and related[entry.uuid]
        and entry.message and entry.message.role == 'assistant' then
      local content = entry.message.content
      if type(content) == 'table' then
        for _, block in ipairs(content) do
          if block.type == 'text' and block.text then
            response_text = (response_text or '') .. block.text .. '\n'
          elseif block.type == 'tool_use' and block.name then
            table.insert(tool_calls, block.name)
          end
        end
      elseif type(content) == 'string' then
        response_text = (response_text or '') .. content .. '\n'
      end
    end
  end

  return response_text, tool_calls
end

function M.find_response(shot_pattern)
  local projects_dir = get_projects_dir()
  local jsonl_files = vim.fn.glob(projects_dir .. '/*.jsonl', false, true)
  if #jsonl_files == 0 then return nil, {} end

  table.sort(jsonl_files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)

  for _, jsonl_path in ipairs(jsonl_files) do
    local response_text, tool_calls = find_response_in_jsonl(jsonl_path, shot_pattern)
    if response_text or #tool_calls > 0 then
      return response_text, tool_calls
    end
  end

  return nil, {}
end

return M

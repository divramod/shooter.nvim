-- AI provider abstraction for shooter.nvim
-- Detects and manages different AI backends (Claude, opencode, etc.)

local utils = require('shooter.utils')

local M = {}

-- Provider registry
M.providers = {}

-- Register a provider
function M.register(name, provider)
  M.providers[name] = provider
end

-- Get process pattern for ps grep (all providers)
function M.get_all_process_patterns()
  local patterns = {}
  for name, provider in pairs(M.providers) do
    if provider.process_pattern then
      table.insert(patterns, provider.process_pattern)
    end
  end
  return patterns
end

-- Get TTYs running any AI process
function M.get_ai_ttys()
  local patterns = M.get_all_process_patterns()
  if #patterns == 0 then return {} end

  local pattern_str = table.concat(patterns, '|')
  local cmd = string.format("ps aux | grep -E '%s' | grep -v grep | awk '{print $7}' 2>/dev/null", pattern_str)
  local handle = io.popen(cmd)
  if not handle then return {} end

  local output = handle:read("*a")
  handle:close()

  local ttys = {}
  for tty in output:gmatch("[^\n]+") do
    local tty_num = tty:match("ttys(%d+)") or tty:match("^s(%d+)$")
    if tty_num then
      ttys[tty_num] = true
    end
  end

  return ttys
end

-- Detect which provider is running on a specific TTY
function M.detect_provider_for_tty(tty_num)
  for name, provider in pairs(M.providers) do
    if provider.process_pattern then
      local cmd = string.format(
        "ps aux | grep -E '%s' | grep -v grep | awk '{print $7}' 2>/dev/null",
        provider.process_pattern
      )
      local handle = io.popen(cmd)
      if handle then
        local output = handle:read("*a")
        handle:close()
        for tty in output:gmatch("[^\n]+") do
          local num = tty:match("ttys(%d+)") or tty:match("^s(%d+)$")
          if num == tty_num then
            return name, provider
          end
        end
      end
    end
  end
  return nil, nil
end

-- Detect provider for a pane ID
function M.detect_provider_for_pane(pane_id)
  local handle = io.popen(string.format("tmux display-message -p -t %s '#{pane_tty}' 2>/dev/null", pane_id))
  if not handle then return nil, nil end

  local tty = handle:read("*a"):gsub("%s+", "")
  handle:close()

  local tty_num = tty:match("ttys(%d+)")
  if not tty_num then return nil, nil end

  return M.detect_provider_for_tty(tty_num)
end

-- Check if any AI is running
function M.check_any_ai_running()
  local patterns = M.get_all_process_patterns()
  if #patterns == 0 then return false end

  local pattern_str = table.concat(patterns, '|')
  local handle = io.popen(string.format("ps aux | grep -E '%s' | grep -v grep 2>/dev/null", pattern_str))
  if not handle then return false end

  local result = handle:read("*a")
  handle:close()

  return result and result ~= ""
end

-- Get provider by name
function M.get_provider(name)
  return M.providers[name]
end

-- Get default provider (Claude for backward compat)
function M.get_default_provider()
  return M.providers.claude
end

-- Load built-in providers
local function load_providers()
  local claude = require('shooter.providers.claude')
  local opencode = require('shooter.providers.opencode')

  M.register('claude', claude)
  M.register('opencode', opencode)
end

load_providers()

return M

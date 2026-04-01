-- AI provider abstraction for shooter.nvim
-- Detects and manages different AI backends (Claude, OpenCode, Codex, Gemini, etc.)

local utils = require('shooter.utils')

local M = {}

-- Provider registry
M.providers = {}

-- Batch-read @shooter_provider tmux pane variables (1 tmux call for all panes)
local function get_all_pane_providers()
  local handle = io.popen("tmux list-panes -a -F '#{pane_id} #{@shooter_provider}' 2>/dev/null")
  if not handle then return {} end
  local output = handle:read("*a")
  handle:close()
  local map = {}
  for line in output:gmatch("[^\n]+") do
    local pane_id, provider = line:match("^(%S+)%s+(%S+)")
    if pane_id and provider and provider ~= "" then
      map[pane_id] = provider
    end
  end
  return map
end

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

-- Get TTYs running any AI process (tmux variables + ps fallback)
function M.get_ai_ttys()
  local ttys = {}

  -- Include TTYs from tmux-variable-detected panes (hal-launched agents)
  local pane_providers = get_all_pane_providers()
  for pane_id, _ in pairs(pane_providers) do
    local handle = io.popen(string.format("tmux display-message -p -t %s '#{pane_tty}' 2>/dev/null", pane_id))
    if handle then
      local tty = handle:read("*a"):gsub("%s+", "")
      handle:close()
      local tty_num = tty:match("ttys(%d+)") or tty:match("^s(%d+)$")
      if tty_num then
        ttys[tty_num] = true
      end
    end
  end

  -- Also include TTYs from ps-based detection (direct agent launches)
  local patterns = M.get_all_process_patterns()
  if #patterns > 0 then
    local pattern_str = table.concat(patterns, '|')
    local cmd = string.format("ps aux | grep -E '%s' | grep -v grep | awk '{print $7}' 2>/dev/null", pattern_str)
    local handle = io.popen(cmd)
    if handle then
      local output = handle:read("*a")
      handle:close()
      for tty in output:gmatch("[^\n]+") do
        local tty_num = tty:match("ttys(%d+)") or tty:match("^s(%d+)$")
        if tty_num then
          ttys[tty_num] = true
        end
      end
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

-- Detect provider for a pane ID (tmux variable first, ps fallback)
function M.detect_provider_for_pane(pane_id)
  -- Try tmux pane variable first (set by hal)
  local pane_providers = get_all_pane_providers()
  local provider_name = pane_providers[pane_id]
  if provider_name and M.providers[provider_name] then
    return provider_name, M.providers[provider_name]
  end

  -- Fall back to ps-based TTY detection (for direct agent launches)
  local handle = io.popen(string.format("tmux display-message -p -t %s '#{pane_tty}' 2>/dev/null", pane_id))
  if not handle then return nil, nil end

  local tty = handle:read("*a"):gsub("%s+", "")
  handle:close()

  local tty_num = tty:match("ttys(%d+)")
  if not tty_num then return nil, nil end

  return M.detect_provider_for_tty(tty_num)
end

-- Check if any AI is running (tmux variable first, ps fallback)
function M.check_any_ai_running()
  -- Check tmux pane variables first (hal-launched agents)
  local pane_providers = get_all_pane_providers()
  if next(pane_providers) then return true end

  -- Fall back to ps-based check (direct agent launches)
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
  local codex = require('shooter.providers.codex')
  local gemini = require('shooter.providers.gemini')
  local copilot = require('shooter.providers.copilot')

  M.register('claude', claude)
  M.register('opencode', opencode)
  M.register('codex', codex)
  M.register('gemini', gemini)
  M.register('copilot', copilot)
end

load_providers()

return M

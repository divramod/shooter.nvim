-- Main entry point for shooter.nvim
-- Setup function and plugin initialization

local M = {}

-- Store initialization state
M._initialized = false
M._config = nil

-- Setup function - must be called by user to initialize the plugin
function M.setup(user_config)
  if M._initialized then
    vim.notify('shooter.nvim is already initialized', vim.log.levels.WARN)
    return M._config
  end

  -- Merge user config with defaults
  local config = require('shooter.config')
  M._config = config.setup(user_config or {})

  -- Register commands
  local commands = require('shooter.commands')
  commands.setup()

  -- Register keymaps (if enabled)
  if M._config.keymaps.enabled then
    local keymaps = require('shooter.keymaps')
    keymaps.setup()

    -- Setup Oil buffer keymaps
    local oil_keymaps = require('shooter.keymaps.oil')
    oil_keymaps.setup()
  end

  -- Setup syntax highlighting for prompt files
  local syntax = require('shooter.syntax')
  syntax.setup()

  M._initialized = true
  return M._config
end


-- Get current configuration
function M.get_config()
  return M._config
end

-- Check if plugin is initialized
function M.is_initialized()
  return M._initialized
end

return M

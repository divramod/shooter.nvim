-- Default configuration for shooter.nvim

local M = {}

-- Default configuration values
M.defaults = {
  -- Path configuration
  paths = {
    -- General context file (shared across all projects)
    general_context = '~/.config/shooter.nvim/shooter-context-general.md',

    -- Project context file (relative to git root)
    project_context = '.shooter.nvim/shooter-context-project.md',

    -- Project context template (in plugin installation)
    project_template = 'templates/shooter-context-project-template.md',

    -- Message template for context injection
    message_template = 'templates/shooter-context-message.md',

    -- Queue file location (relative to cwd)
    queue_file = 'plans/prompts/.shot-queue.json',

    -- Prompts root directory (relative to cwd)
    prompts_root = 'plans/prompts',

    -- Prompts directory (computed dynamically)
    prompts_dir = vim.fn.getcwd() .. '/plans/prompts',
  },

  -- Tmux configuration
  tmux = {
    -- Delay between send operations (seconds)
    delay = 0.2,

    -- Delay for long messages
    long_delay = 1.5,

    -- Maximum number of panes supported
    max_panes = 9,

    -- Threshold for long messages (characters)
    long_message_threshold = 5000,

    -- Threshold for long messages (lines)
    long_message_lines = 50,
  },

  -- Telescope configuration
  telescope = {
    -- Default layout strategy
    layout_strategy = 'vertical',

    -- Default layout config
    layout_config = {
      width = 0.9,
      height = 0.9,
      preview_height = 0.5,
    },
  },

  -- Keymaps configuration
  keymaps = {
    -- Enable default keymaps
    enabled = true,

    -- Key prefix (space)
    prefix = ' ',

    -- Move command prefix (m)
    move_prefix = 'm',

    -- Copy command prefix (c)
    copy_prefix = 'c',
  },

  -- File patterns
  patterns = {
    -- Shot header pattern
    shot_header = '^##%s+x?%s*shot',

    -- Open shot header pattern (not marked with x)
    open_shot_header = '^##%s+shot',

    -- Executed shot header pattern (marked with x)
    executed_shot_header = '^##%s+x%s+shot',

    -- Image reference pattern
    image_ref = '^img(%d+):',
  },

  -- Feature flags
  features = {
    -- Enable queue system
    queue_enabled = true,

    -- Enable context injection
    context_enabled = true,

    -- Enable image insertion
    images_enabled = true,

    -- Enable PRD integration
    prd_enabled = true,
  },
}

-- Current configuration (will be merged with user config)
M.current = vim.deepcopy(M.defaults)

-- Setup function to merge user config
function M.setup(user_config)
  M.current = vim.tbl_deep_extend('force', M.defaults, user_config or {})
  return M.current
end

-- Get config value by path (e.g., 'tmux.delay')
function M.get(path)
  local keys = vim.split(path, '%.', { plain = true })
  local value = M.current

  for _, key in ipairs(keys) do
    if type(value) ~= 'table' then
      return nil
    end
    value = value[key]
  end

  return value
end

-- Set config value by path
function M.set(path, new_value)
  local keys = vim.split(path, '%.', { plain = true })
  local value = M.current

  for i = 1, #keys - 1 do
    local key = keys[i]
    if type(value[key]) ~= 'table' then
      value[key] = {}
    end
    value = value[key]
  end

  value[keys[#keys]] = new_value
end

return M

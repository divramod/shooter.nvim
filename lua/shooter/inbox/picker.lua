-- Telescope pickers for inbox "get munition" feature
-- File picker and action picker with multi-select

local inbox = require('shooter.inbox')
local utils = require('shooter.utils')

local M = {}

-- Show file picker for inbox files
function M.show_file_picker()
  local files = inbox.get_inbox_files()
  if #files == 0 then
    utils.notify('No inbox files configured. Add inbox.search_dirs or inbox.direct_paths to config', vim.log.levels.WARN)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers = require('telescope.previewers')

  pickers.new({}, {
    prompt_title = 'Select Inbox File',
    finder = finders.new_table({
      results = files,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.name,
          path = entry.path,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = 'File Content',
      define_preview = function(self, entry)
        local content = utils.read_file(entry.path) or ''
        local lines = vim.split(content, '\n')
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    }),
    layout_strategy = 'vertical',
    layout_config = { width = 0.9, height = 0.9, preview_height = 0.5 },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          M.show_action_picker(entry.value.path)
        end
      end)
      return true
    end,
  }):find()
end

-- Show action picker with multi-select for a specific file
function M.show_action_picker(filepath)
  local next_actions = inbox.parse_next_actions(filepath)
  if #next_actions == 0 then
    utils.notify('No next actions found in file', vim.log.levels.INFO)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers = require('telescope.previewers')

  pickers.new({}, {
    prompt_title = 'Select Actions (Tab/Space=select, Enter=import)',
    finder = finders.new_table({
      results = next_actions,
      entry_maker = function(entry)
        local prefix = entry.type == 'checkbox' and '☐ ' or '# '
        return {
          value = entry,
          display = prefix .. entry.title,
          ordinal = entry.title,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = 'Action Content',
      define_preview = function(self, entry)
        local content = inbox.get_action_content(entry.value)
        local lines = vim.split(content, '\n')
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    }),
    layout_strategy = 'vertical',
    layout_config = { width = 0.9, height = 0.9, preview_height = 0.5 },
    initial_mode = 'normal',
    attach_mappings = function(prompt_bufnr, map)
      -- Toggle selection with Tab (use telescope's built-in)
      map('n', '<Tab>', function()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_next(prompt_bufnr)
      end)
      -- Space also toggles selection and moves down
      map('n', '<space>', function()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_next(prompt_bufnr)
      end)

      -- Import selected actions on Enter
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multi = picker:get_multi_selection()

        local to_import = {}
        if #multi > 0 then
          for _, entry in ipairs(multi) do
            table.insert(to_import, entry.value)
          end
        else
          -- No multi-selection, use current entry
          local entry = action_state.get_selected_entry()
          if entry then
            table.insert(to_import, entry.value)
          end
        end

        actions.close(prompt_bufnr)

        if #to_import > 0 then
          M.import_actions(to_import, filepath)
        end
      end)

      return true
    end,
  }):find()
end

-- Import selected actions as new shots and remove from source
function M.import_actions(actions_to_import, source_filepath)
  local shots = require('shooter.core.shots')

  -- Sort by start_line descending (so we remove from bottom first)
  table.sort(actions_to_import, function(a, b) return a.start_line > b.start_line end)

  -- Get current buffer
  local bufnr = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(bufnr)

  -- Check we're in a shooter file
  if not current_file:match('%.md$') then
    utils.notify('Current file must be a markdown file', vim.log.levels.WARN)
    return
  end

  -- Find highest shot number (get_next_shot_number returns max + 1, so subtract 1)
  local highest = shots.get_next_shot_number(bufnr) - 1

  -- Add shots in reverse order (so first selected becomes highest number)
  local added = 0
  for i = #actions_to_import, 1, -1 do
    local action = actions_to_import[i]
    highest = highest + 1

    -- Create shot content
    local shot_content = action.title
    if action.type == 'header' and #action.lines > 1 then
      -- Include header content (skip the header line itself)
      local content_lines = {}
      for j = 2, #action.lines do
        table.insert(content_lines, action.lines[j])
      end
      local extra = table.concat(content_lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      if extra ~= '' then
        shot_content = shot_content .. '\n' .. extra
      end
    end

    -- Always insert at line 3 (after title on line 1 and empty line on line 2)
    -- Format: Line 1 = # Title, Line 2 = empty, Line 3 = ## shot N
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Ensure line 2 is empty (index 1)
    if #lines < 2 then
      vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { '' })
    elseif lines[2] ~= '' then
      vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { '' })
    end

    -- Build shot lines: header + content + trailing empty line for next shot
    local shot_lines = { '## shot ' .. highest }
    for line in shot_content:gmatch('[^\n]*') do
      table.insert(shot_lines, line)
    end
    table.insert(shot_lines, '')  -- Empty line after content

    -- Insert at line 3 (index 2)
    vim.api.nvim_buf_set_lines(bufnr, 2, 2, false, shot_lines)
    added = added + 1
  end

  -- Remove from source file
  inbox.remove_actions_from_file(source_filepath, actions_to_import)

  -- Save current buffer
  vim.cmd('write')

  utils.notify(string.format('Imported %d action(s) as new shots', added), vim.log.levels.INFO)
end

return M

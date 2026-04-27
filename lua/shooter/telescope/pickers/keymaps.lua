-- Shared keymap setup for the file/shot pickers: folder toggles and the
-- session command prefix (ss/sl/sn/sd/sr).
local M = {}

local actions = require('telescope.actions')
local session = require('shooter.session')
local session_picker = require('shooter.session.picker')

function M.setup_folder_mappings(prompt_bufnr, map, refresh_fn)
  local folder_keys = {
    ['1'] = 'archive', ['a'] = 'archive',
    ['2'] = 'backlog', ['b'] = 'backlog',
    ['3'] = 'done', ['t'] = 'done',
    ['4'] = 'reqs', ['e'] = 'reqs',
    ['5'] = 'wait', ['w'] = 'wait',
    ['6'] = 'prompts', ['f'] = 'prompts',
  }
  for key, folder in pairs(folder_keys) do
    map('n', key, function()
      local _ = session.toggle_folder(folder)
      refresh_fn(prompt_bufnr)
    end, { desc = 'toggle: ' .. folder })
  end
  map('n', 'A', function()
    local _ = session.toggle_all_folders()
    refresh_fn(prompt_bufnr)
  end, { desc = 'toggle all folders' })
end

function M.setup_session_mappings(prompt_bufnr, map, refresh_fn, list_all_files)
  map('n', 'ss', function()
    session.save_current()
  end, { desc = 'save session' })

  map('n', 'sl', function()
    actions.close(prompt_bufnr)
    session_picker.show_session_picker(function()
      list_all_files({ initial_mode = 'normal' }):find()
    end)
  end, { desc = 'load session' })

  map('n', 'sn', function()
    actions.close(prompt_bufnr)
    session_picker.show_new_session_prompt(function()
      list_all_files({ initial_mode = 'normal' }):find()
    end)
  end, { desc = 'new session' })

  map('n', 'sd', function()
    vim.ui.input({ prompt = 'Delete session? (y/n): ' }, function(confirm)
      if confirm == 'y' then
        session.delete_current_session()
        refresh_fn(prompt_bufnr)
      end
    end)
  end, { desc = 'delete session' })

  map('n', 'sr', function()
    actions.close(prompt_bufnr)
    session_picker.show_rename_prompt(function()
      list_all_files({ initial_mode = 'normal' }):find()
    end)
  end, { desc = 'rename session' })
end

return M

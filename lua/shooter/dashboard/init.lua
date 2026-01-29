-- Dashboard module: Three-step drill-down picker
-- Step 1: Repos -> Step 2: Files -> Step 3: Shots

local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local data = require('shooter.dashboard.data')

local layout = { layout_strategy = 'vertical', layout_config = { width = 0.9, height = 0.9, preview_height = 0.4 }, initial_mode = 'normal' }

-- Common mappings for all pickers
local function common_mappings(pb, map, back_fn)
  map('n', 'q', function() actions.close(pb) end)
  map('n', '<C-n>', function() actions.move_selection_next(pb) end)
  map('n', '<C-p>', function() actions.move_selection_previous(pb) end)
  map('i', '<C-n>', function() actions.move_selection_next(pb) end)
  map('i', '<C-p>', function() actions.move_selection_previous(pb) end)
  if back_fn then map('n', 'H', function() actions.close(pb); back_fn() end) end
end

-- Step 3: Show open shots in a file
local function show_shots(file_entry, back_fn)
  if #file_entry.shots == 0 then vim.notify('No open shots', vim.log.levels.INFO); return end

  pickers.new({}, vim.tbl_extend('force', layout, {
    prompt_title = 'Shots: ' .. file_entry.title,
    finder = finders.new_table({
      results = file_entry.shots,
      entry_maker = function(shot)
        local disp = string.format('shot %s: %s', shot.display_num or shot.number or '?', shot.preview or '')
        return { value = { shot = shot, file = file_entry }, display = disp, ordinal = disp }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = 'Shot Content',
      define_preview = function(self, entry)
        if not entry or not entry.value then return end
        local f = io.open(entry.value.file.path, 'r')
        if not f then return end
        local lines, in_shot, ln = {}, false, 0
        for line in f:lines() do
          ln = ln + 1
          if ln == entry.value.shot.line then in_shot = true
          elseif in_shot and line:match('^##%s+x?%s*shot') then break end
          if in_shot then table.insert(lines, line) end
        end
        f:close()
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
      end,
    }),
    attach_mappings = function(pb, map)
      common_mappings(pb, map, back_fn)
      actions.select_default:replace(function()
        local e = action_state.get_selected_entry()
        actions.close(pb)
        if e and e.value then
          vim.cmd('edit ' .. vim.fn.fnameescape(e.value.file.path))
          vim.api.nvim_win_set_cursor(0, { e.value.shot.line, 0 })
          vim.cmd('normal! zz')
        end
      end)
      for i = 1, 4 do
        map('n', tostring(i), function()
          local e = action_state.get_selected_entry()
          if not e or not e.value then return end
          actions.close(pb)
          vim.cmd('edit ' .. vim.fn.fnameescape(e.value.file.path))
          vim.api.nvim_win_set_cursor(0, { e.value.shot.line, 0 })
          vim.schedule(function() vim.cmd('ShooterSend' .. i) end)
        end)
      end
      return true
    end,
  })):find()
end

-- Step 2: Show in-progress files in a repo
local function show_files(repo, back_fn)
  if #repo.files == 0 then vim.notify('No in-progress files', vim.log.levels.INFO); return end

  pickers.new({}, vim.tbl_extend('force', layout, {
    prompt_title = string.format('Files: %s (%d/%d open)', repo.name, repo.open_shots, repo.total_shots),
    finder = finders.new_table({
      results = repo.files,
      entry_maker = function(file)
        local t = file.title or file.name
        if #t > 40 then t = t:sub(1, 37) .. '...' end
        return { value = file, display = string.format('%s (%d/%d)', t, file.open_count, file.total_count), ordinal = file.title or file.name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = 'Open Shots',
      define_preview = function(self, entry)
        if not entry or not entry.value then return end
        local lines = { '# ' .. (entry.value.title or entry.value.name), '' }
        for _, shot in ipairs(entry.value.shots) do
          table.insert(lines, string.format('## shot %s', shot.display_num or shot.number or '?'))
          if shot.preview then table.insert(lines, shot.preview) end
          table.insert(lines, '')
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
      end,
    }),
    attach_mappings = function(pb, map)
      common_mappings(pb, map, back_fn)
      actions.select_default:replace(function()
        local e = action_state.get_selected_entry()
        actions.close(pb)
        if e and e.value then show_shots(e.value, function() show_files(repo, back_fn) end) end
      end)
      return true
    end,
  })):find()
end

-- Step 1: Show all repos
local function show_repos()
  local repos = data.get_all_repos()
  if #repos == 0 then vim.notify('No repos with open shots found', vim.log.levels.INFO); return end

  pickers.new({}, vim.tbl_extend('force', layout, {
    prompt_title = 'Dashboard: Select Repo',
    finder = finders.new_table({
      results = repos,
      entry_maker = function(repo)
        return {
          value = repo,
          display = string.format('%s (%d/%d files) [%d/%d shots]', repo.name, repo.files_with_shots, repo.total_files, repo.open_shots, repo.total_shots),
          ordinal = repo.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = 'Repo Files',
      define_preview = function(self, entry)
        if not entry or not entry.value then return end
        local lines = { '# ' .. entry.value.name, '' }
        for _, file in ipairs(entry.value.files) do
          table.insert(lines, string.format('- %s (%d/%d shots)', file.title or file.name, file.open_count, file.total_count))
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
      end,
    }),
    attach_mappings = function(pb, map)
      common_mappings(pb, map, nil)
      actions.select_default:replace(function()
        local e = action_state.get_selected_entry()
        actions.close(pb)
        if e and e.value then show_files(e.value, show_repos) end
      end)
      return true
    end,
  })):find()
end

function M.open() show_repos() end
function M.toggle() M.open() end

return M

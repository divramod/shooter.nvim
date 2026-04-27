-- Test suite for shooter.telescope.pickers module.
-- Telescope isn't installed in CI, so stub the small surface pickers.lua
-- consumes (pickers.new, finders.new_table, conf.values.generic_sorter,
-- actions.{select_default, close, move_selection_*, toggle_selection},
-- action_state.get_*). The stubs let us assert picker construction
-- (title, layout, finder shape) without running telescope.

local captured_pickers

local function reset_capture()
  captured_pickers = {}
end

local function fake_picker_instance(opts)
  local prompt_border = {
    change_title = function(_, _) end,
  }
  -- Capture map() registrations so we cover the attach_mappings body.
  local mappings = {}
  local function fake_map(mode, key, fn, _)
    table.insert(mappings, { mode = mode, key = key, fn = fn })
  end
  if opts.attach_mappings then
    pcall(opts.attach_mappings, 0, fake_map)
  end
  return {
    _opts = opts,
    _multi = { drop_all = function(_) end },
    _mappings = mappings,
    finder = opts.finder,
    prompt_border = prompt_border,
    find = function(_) end,
    refresh = function(_, _, _) end,
    get_multi_selection = function(_) return {} end,
    get_selection_row = function(_) return 0 end,
    set_selection = function(_, _) end,
    manager = nil,
  }
end

local function stub_telescope()
  package.loaded['telescope.pickers'] = {
    new = function(_, picker_opts)
      table.insert(captured_pickers, picker_opts)
      return fake_picker_instance(picker_opts)
    end,
  }
  package.loaded['telescope.finders'] = {
    new_table = function(opts) return { _kind = 'finder', _opts = opts } end,
  }
  package.loaded['telescope.config'] = {
    values = { generic_sorter = function(_) return { _kind = 'sorter' } end },
  }
  package.loaded['telescope.actions'] = {
    select_default = { replace = function(_, _) end },
    close = function(_) end,
    move_selection_next = function(_) end,
    move_selection_previous = function(_) end,
    toggle_selection = function(_) end,
  }
  package.loaded['telescope.actions.state'] = {
    get_current_picker = function(_) return nil end,
    get_selected_entry = function() return nil end,
  }
end

reset_capture()
stub_telescope()

-- shooter.telescope.previewers, .actions, .picker_help, .recency:
-- shim stubs so pickers.lua loads without their telescope deps.
package.loaded['shooter.telescope.previewers'] = {
  file_previewer = function() return { _kind = 'previewer' } end,
  shot_previewer = function() return { _kind = 'shot-previewer' } end,
}
package.loaded['shooter.telescope.actions'] = {
  send_multiple_shots = function(_, _) end,
  delete_shot = function(_, _, _) end,
}
package.loaded['shooter.telescope.picker_help'] = {
  show_shotfile_help = function() end,
  show_shots_help = function() end,
}
-- recency is already pure-Lua; do not stub, let it load real.

-- session deps
package.loaded['shooter.session'] = {
  get_current_session = function()
    return {
      name = 'default',
      vimMode = { shotfilePicker = 'insert', shotPicker = 'normal' },
      layout = 'vertical',
    }
  end,
  get_current_session_name = function() return 'default' end,
  get_session_file_path = function() return '/tmp/sess.yml' end,
  reload_from_disk = function() end,
  toggle_folder = function(_) return true end,
  toggle_all_folders = function() return true end,
  toggle_layout = function() return 'horizontal' end,
  delete_current_session = function() end,
  save_current = function() end,
}
package.loaded['shooter.session.filter'] = {
  get_filter_status = function(_) return 'all' end,
  apply_filters = function(files, _, _) return files end,
}
package.loaded['shooter.session.sort'] = {
  get_sort_status = function(_) return 'default' end,
  clear_cache = function() end,
  sort_files = function(files, _) return files end,
}
package.loaded['shooter.session.picker'] = {
  show_session_picker = function(_) end,
  show_new_session_prompt = function(_) end,
  show_rename_prompt = function(_) end,
  show_project_picker = function(_) end,
  show_sort_picker = function(_) end,
}
package.loaded['shooter.config'] = {
  get = function(_) return ' ' end,
}
package.loaded['shooter.tools.git_worktree'] = {
  get_main_worktree = function() return '/tmp/repo' end,
}
package.loaded['shooter.utils'] = {
  echo = function(_) end,
  cwd = function() return '/tmp/repo' end,
  dir_exists = function(_) return false end,
}
package.loaded['shooter.core.files'] = {
  get_git_root = function() return '/tmp/repo' end,
  open_shotfile = function(_) end,
  is_in_prompts_folder = function(_) return false end,
  find_last_file = function() return '/tmp/repo/docs/shotfiles/last.md' end,
  slugify_path = function(p) return p end,
  generate_filename = function(n) return n .. '.md' end,
  title_from_path = function(_) return 'Title' end,
}
-- Real helpers (already covered by helpers_spec) — provide stubs that
-- pickers.lua treats as data sources.
package.loaded['shooter.telescope.helpers'] = {
  clear_selection = function(_) end,
  get_target_file = function() return '/tmp/repo/docs/shotfiles/x.md', false end,
  read_lines = function(_, _) return { '## shot 1', 'body' } end,
  find_open_shots = function(_) return { { header_line = 1, start_line = 1, end_line = 2 } } end,
  make_shot_entry = function(_, _, _, _, _)
    return { display = 'Shot 1: body', shot_num = '1', header_line = 1, start_line = 1, end_line = 2, target_file = '/x.md' }
  end,
  get_repo_prompt_files = function() return {} end,
  get_all_repo_shots = function() return { { display = 'Shot 1: x', shot_num = '1' } } end,
  get_prompt_files = function(_) return { { display = 'a.md', path = '/a.md' } } end,
  get_all_repos_prompt_files = function(_) return { { display = 'b.md', path = '/b.md' } } end,
  get_bullet_files = function(opts)
    if opts.scope == 'file' then return {} end
    return { { display = 'bullet.md', path = '/bullet.md', _mtime = os.time() } }
  end,
  save_selection_state = function(_, _) end,
  restore_selection_state = function(_, _, _) end,
}
package.loaded['shooter.keymaps.picker'] = {
  setup_nav_keymaps = function(_) end,
}
package.loaded['shooter.core.movement'] = {
  move_file_path = function(_, _) return true end,
}
package.loaded['shooter.core.rename'] = {
  rename_current_file = function() end,
}
package.loaded['shooter.core.shot_actions'] = {
  toggle_shot_done = function() end,
}

package.loaded['shooter.telescope.pickers'] = nil
local pickers = require('shooter.telescope.pickers')

describe('telescope pickers', function()
  describe('module structure', function()
    it('exports the expected entry points', function()
      assert.is_function(pickers.list_all_files)
      assert.is_function(pickers.list_all_repos_files)
      assert.is_function(pickers.list_open_shots)
      assert.is_function(pickers.list_bullets_current_file)
      assert.is_function(pickers.list_bullets_current_repo)
      assert.is_function(pickers.list_bullets_all_repos)
      assert.is_function(pickers.clear_selection)
      assert.is_string(pickers.shot_picker_mode)
      assert.is_true(pickers.shot_picker_mode == 'current'
        or pickers.shot_picker_mode == 'all')
    end)
  end)

  describe('list_all_files', function()
    it('constructs a picker with title and finder', function()
      reset_capture()
      local picker = pickers.list_all_files({})
      assert.is_not_nil(picker)
      assert.are.equal(1, #captured_pickers)
      local opts = captured_pickers[1]
      assert.is_string(opts.prompt_title)
      assert.is_truthy(opts.prompt_title:match('%[default'))  -- session name in title
      assert.is_truthy(opts.prompt_title:match('%(?=help%)'))  -- help hint
      assert.is_table(opts.finder)
      assert.are.equal('finder', opts.finder._kind)
      assert.is_table(opts.sorter)
      assert.is_table(opts.previewer)
      assert.is_function(opts.attach_mappings)
      assert.are.equal('vertical', opts.layout_strategy)
    end)

    it('honors initial_mode override', function()
      reset_capture()
      pickers.list_all_files({ initial_mode = 'normal' })
      assert.are.equal('normal', captured_pickers[1].initial_mode)
    end)
  end)

  describe('list_all_repos_files', function()
    it('constructs a picker for all repos', function()
      reset_capture()
      local picker = pickers.list_all_repos_files({})
      assert.is_not_nil(picker)
      assert.are.equal(1, #captured_pickers)
      assert.is_truthy(captured_pickers[1].prompt_title:match('All Repos'))
    end)
  end)

  describe('list_open_shots', function()
    it('constructs a picker when shots are present', function()
      reset_capture()
      pickers.shot_picker_mode = 'current'
      local picker = pickers.list_open_shots({})
      assert.is_not_nil(picker)
      assert.are.equal(1, #captured_pickers)
      local opts = captured_pickers[1]
      assert.is_truthy(opts.prompt_title:match('Open Shots'))
      assert.are.equal('vertical', opts.layout_strategy)
    end)

    it('returns nothing when no shots', function()
      local h = package.loaded['shooter.telescope.helpers']
      local original_find = h.find_open_shots
      local original_get_all = h.get_all_repo_shots
      h.find_open_shots = function(_) return {} end
      h.get_all_repo_shots = function() return {} end
      reset_capture()
      pickers.shot_picker_mode = 'current'
      local picker = pickers.list_open_shots({})
      assert.is_nil(picker)
      h.find_open_shots = original_find
      h.get_all_repo_shots = original_get_all
    end)

    it('constructs an all-repo picker when mode is all', function()
      reset_capture()
      pickers.shot_picker_mode = 'all'
      local picker = pickers.list_open_shots({})
      assert.is_not_nil(picker)
      assert.is_truthy(captured_pickers[1].prompt_title:match('All Repo Shots'))
      pickers.shot_picker_mode = 'current'
    end)
  end)

  describe('list_bullets_current_file', function()
    it('returns nothing when not in a git repo', function()
      -- Empty list triggers `#root == 0` → get_repo_slug returns nil
      local original = vim.fn.systemlist
      vim.fn.systemlist = function(_) return {} end
      local picker = pickers.list_bullets_current_file()
      assert.is_nil(picker)
      vim.fn.systemlist = original
    end)

    it('returns nothing when no bullets', function()
      local original = vim.fn.systemlist
      vim.fn.systemlist = function(_) return { '/tmp/repo' } end
      reset_capture()
      local picker = pickers.list_bullets_current_file()
      assert.is_nil(picker)  -- helpers stub returns {} for scope=file
      vim.fn.systemlist = original
    end)
  end)

  describe('list_bullets_current_repo', function()
    it('returns nothing when not in a git repo', function()
      local original = vim.fn.systemlist
      vim.fn.systemlist = function(_) return {} end
      local picker = pickers.list_bullets_current_repo()
      assert.is_nil(picker)
      vim.fn.systemlist = original
    end)

    it('constructs a picker when bullets exist', function()
      local original = vim.fn.systemlist
      vim.fn.systemlist = function(_) return { '/tmp/repo' } end
      reset_capture()
      local picker = pickers.list_bullets_current_repo()
      assert.is_not_nil(picker)
      assert.is_truthy(captured_pickers[1].prompt_title:match('Bullets'))
      vim.fn.systemlist = original
    end)
  end)

  describe('list_bullets_all_repos', function()
    it('constructs a picker spanning all repos', function()
      reset_capture()
      local picker = pickers.list_bullets_all_repos()
      assert.is_not_nil(picker)
      assert.is_truthy(captured_pickers[1].prompt_title:match('All Repos'))
    end)
  end)

  describe('clear_selection re-export', function()
    it('is callable without errors', function()
      assert.has_no.errors(function() pickers.clear_selection('/x.md') end)
      assert.has_no.errors(function() pickers.clear_selection() end)
    end)
  end)
end)

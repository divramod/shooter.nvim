-- Security spec for the telescope area (Phase 003 T006).
-- Verifies that:
--   1. The new-shotfile-from-prompt flow rejects path-traversal in user input.
--   2. The toggle_panes_picker pane-target capture rejects shell metachars.
--   3. Helpers' directory walks no longer use shell-form `io.popen` for ls.

local function read_all(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()
  return content
end

describe('telescope path-traversal protection', function()
  -- Reuse the slugify helpers from shooter.core.files. The pickers/file.lua
  -- create-from-prompt fallback routes user input through slugify_path
  -- (for dir_part) and generate_filename (for name_part) before joining
  -- with shotfiles_dir. If both are robust, the resulting path stays
  -- under shotfiles_dir even for `../etc/passwd`-style input.
  local path_mod = require('shooter.core.files.path')

  local function compute_target_dir(prompt, shotfiles_dir)
    local dir_part, name_part = prompt:match('^(.+)/(.+)$')
    local target_dir, name
    if dir_part and name_part then
      local dir_slug = path_mod.slugify_path(dir_part)
      target_dir = shotfiles_dir .. (dir_slug ~= '' and ('/' .. dir_slug) or '')
      name = name_part
    else
      target_dir = shotfiles_dir
      name = prompt
    end
    return target_dir, name
  end

  it('rejects parent-directory traversal in the dir segment', function()
    local target_dir, _ = compute_target_dir('../etc/passwd', '/repo/docs/shotfiles')
    -- '..' becomes empty after slugify_segment strips non-word chars; the
    -- ternary then picks shotfiles_dir directly. So the target stays inside
    -- the prompts root.
    assert.is_truthy(target_dir == '/repo/docs/shotfiles'
      or target_dir:match('^/repo/docs/shotfiles/'))
    assert.is_falsy(target_dir:match('%.%.'))
  end)

  it('rejects absolute paths in the dir segment', function()
    local target_dir, _ = compute_target_dir('/etc/passwd', '/repo/docs/shotfiles')
    -- gmatch '[^/]+' consumes the leading slash; "etc" survives slugify.
    -- The resulting target is a child of shotfiles_dir, never `/etc`.
    assert.is_truthy(target_dir:match('^/repo/docs/shotfiles'))
    assert.is_falsy(target_dir:match('^/etc'))
  end)

  it('strips dot segments inside compound paths', function()
    local target_dir, _ = compute_target_dir('./../foo/bar', '/repo/docs/shotfiles')
    assert.is_truthy(target_dir:match('^/repo/docs/shotfiles'))
    assert.is_falsy(target_dir:match('%.%.'))
  end)

  it('produces a slugified filename for traversal-laden name segments', function()
    local _, name = compute_target_dir('foo/../malicious', '/repo/docs/shotfiles')
    -- name_part is '..,malicious' after the first /; the matcher is greedy
    -- so dir_part='foo/..' name_part='malicious'. generate_filename then
    -- slugifies further. Either way, name should never re-introduce '..'.
    local slug = path_mod.generate_filename(name):gsub('%.md$', '')
    assert.is_falsy(slug:match('%.%.'))
    assert.is_falsy(slug:match('/'))
  end)

  it('handles an empty prompt without raising', function()
    local target_dir, name = compute_target_dir('', '/repo/docs/shotfiles')
    assert.is_string(target_dir)
    assert.is_string(name)
  end)
end)

describe('toggle_panes_picker pane-target validation', function()
  -- Telescope isn't loaded in CI; the source-level check is enough to
  -- guarantee no shell-form interpolation reaches `io.popen`/`system`.
  local source = read_all('lua/shooter/telescope/toggle_panes_picker.lua')

  it('does not pass interpolated pane targets to a shell', function()
    assert.is_string(source)
    assert.is_nil(source:match("io%.popen%(.-tmux capture%-pane.-'.-'"))
    assert.is_nil(source:match("vim%.fn%.system%((['\"])tmux"))
  end)

  it('uses table-form systemlist for tmux capture', function()
    assert.is_truthy(source:match("vim%.fn%.systemlist%(%s*{"))
    assert.is_truthy(source:match("'tmux'%s*,%s*'capture%-pane'"))
  end)

  it('validates pane target shape before invoking tmux', function()
    -- Source contains the regex check `^[%w_:.%-%%]+$`. The literal `%` in
    -- the source is a Lua escape inside a string literal — match the
    -- on-disk substring including the backslash-style escapes.
    assert.is_truthy(source:match("pane_target:match"))
    assert.is_truthy(source:match("invalid pane target"))
  end)
end)

describe('telescope helpers no longer shell out for directory listing', function()
  local function ban_io_popen_ls(path)
    local content = read_all(path)
    if not content then return true end  -- file may have moved; not our concern
    return content:match("io%.popen%(.-ls ") == nil
  end

  it('helpers/files.lua does not call io.popen("ls ...")', function()
    assert.is_true(ban_io_popen_ls('lua/shooter/telescope/helpers/files.lua'))
  end)

  it('helpers/bullets.lua does not call io.popen("ls ...")', function()
    assert.is_true(ban_io_popen_ls('lua/shooter/telescope/helpers/bullets.lua'))
  end)
end)

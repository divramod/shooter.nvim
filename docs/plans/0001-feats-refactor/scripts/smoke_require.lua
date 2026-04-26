-- Smoke-require enumerator for plan 0001-feats-refactor (Success Criterion #6).
-- Walks lua/shooter/**/*.lua and asserts every module loads on a fresh Neovim.
-- Exit code is the count of failed requires (0 = all good).
--
-- Usage:
--   nvim --headless -u tests/minimal_init.lua \
--     -c "luafile docs/plans/0001-feats-refactor/scripts/smoke_require.lua" -c qa!

local lua_root = 'lua'
local cwd = vim.fn.getcwd()
local files = vim.fn.globpath(cwd .. '/' .. lua_root, '**/*.lua', false, true)

if #files == 0 then
  io.stderr:write('FAIL  no Lua files found under ' .. lua_root .. '/\n')
  os.exit(2)
end

-- Convert "<cwd>/lua/shooter/foo/bar.lua" → "shooter.foo.bar"
-- Convert "<cwd>/lua/shooter/foo/init.lua" → "shooter.foo"
local function path_to_require(path)
  local relative = path:sub(#cwd + 2)         -- strip cwd + leading "/"
  relative = relative:gsub('^' .. lua_root .. '/', '')
  relative = relative:gsub('%.lua$', '')
  relative = relative:gsub('/init$', '')
  return (relative:gsub('/', '.'))
end

local ok_count, fail_count = 0, 0
local failures = {}

for _, path in ipairs(files) do
  local mod = path_to_require(path)
  -- Skip empty / synthetic
  if mod ~= '' then
    -- Each require runs in isolation: clear cached entry first to get a real load.
    package.loaded[mod] = nil
    local ok, err = pcall(require, mod)
    if ok then
      ok_count = ok_count + 1
      print('OK    ' .. mod)
    else
      fail_count = fail_count + 1
      failures[#failures + 1] = mod .. ' :: ' .. tostring(err):gsub('\n.*', '')
      print('FAIL  ' .. mod .. ' :: ' .. tostring(err):gsub('\n.*', ''))
    end
  end
end

print(('SUMMARY  %d ok / %d fail (%d total)'):format(ok_count, fail_count, ok_count + fail_count))

if fail_count > 0 then
  io.stderr:write('\nFAILURES:\n')
  for _, f in ipairs(failures) do
    io.stderr:write('  - ' .. f .. '\n')
  end
end

os.exit(fail_count)

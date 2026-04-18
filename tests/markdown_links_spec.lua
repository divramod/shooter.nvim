local ml = require('shooter.markdown_links')

local function extract(line, ranges)
  local out = {}
  for _, r in ipairs(ranges) do
    table.insert(out, line:sub(r[1] + 1, r[2]))
  end
  return out
end

describe('shooter.markdown_links', function()
  describe('find_ranges', function()
    it('matches markdown inline link', function()
      local line = 'see [docs](https://example.com/x) here'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ '[docs](https://example.com/x)' }, spans)
    end)

    it('matches bare http url', function()
      local line = 'go to https://nvim.io/docs today'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ 'https://nvim.io/docs' }, spans)
    end)

    it('matches tilde home path with extension', function()
      local line = 'see ~/a/shooter.nvim/.hal/util/shooter/shotfiles/feats.md end'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ '~/a/shooter.nvim/.hal/util/shooter/shotfiles/feats.md' }, spans)
    end)

    it('matches absolute path', function()
      local line = 'open /tmp/foo.txt'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ '/tmp/foo.txt' }, spans)
    end)

    it('matches relative ./ path', function()
      local line = 'open ./src/main.lua please'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ './src/main.lua' }, spans)
    end)

    it('matches relative ../ path', function()
      local line = 'open ../lib/init.lua'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ '../lib/init.lua' }, spans)
    end)

    it('matches slashed path with extension', function()
      local line = 'edit lua/shooter/core/shotfile_fix.lua now'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ 'lua/shooter/core/shotfile_fix.lua' }, spans)
    end)

    it('does not match bare slashes without extension', function()
      local line = 'foo / bar / baz'
      assert.same({}, ml.find_ranges(line))
    end)

    it('matches multiple ranges in one line', function()
      local line = 'see [x](https://a.b) and ~/.config/init.lua here'
      local spans = extract(line, ml.find_ranges(line))
      assert.same({ '[x](https://a.b)', '~/.config/init.lua' }, spans)
    end)

    it('returns empty for plain prose', function()
      assert.same({}, ml.find_ranges('this is just prose with no links'))
    end)

    it('does not double-match url inside markdown link', function()
      local line = 'see [docs](https://example.com/x) end'
      local ranges = ml.find_ranges(line)
      assert.equals(1, #ranges)
    end)
  end)
end)

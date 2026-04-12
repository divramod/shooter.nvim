-- Tests for shooter.core.move_picker
local move_picker = require('shooter.core.move_picker')
local utils = require('shooter.utils')

describe('shooter.core.move_picker', function()
  describe('parse_move_prompt', function()
    local root = '/repo/.hal/shooter/shotfiles'

    it('returns nil for an empty prompt', function()
      assert.is_nil(move_picker.parse_move_prompt('', root))
      assert.is_nil(move_picker.parse_move_prompt(nil, root))
    end)

    it('parses a trailing slash as keep-name into the given folder', function()
      local dir, basename = move_picker.parse_move_prompt('apps/next/', root)
      assert.equals(root .. '/apps/next', dir)
      assert.is_nil(basename)
    end)

    it('parses a rename path into (parent_dir, <name>.md)', function()
      local dir, basename = move_picker.parse_move_prompt('apps/next/domain', root)
      assert.equals(root .. '/apps/next', dir)
      assert.equals('domain.md', basename)
    end)

    it('handles nested rename paths', function()
      local dir, basename = move_picker.parse_move_prompt('a/b/c/d', root)
      assert.equals(root .. '/a/b/c', dir)
      assert.equals('d.md', basename)
    end)

    it('handles nested keep-name paths', function()
      local dir, basename = move_picker.parse_move_prompt('a/b/c/', root)
      assert.equals(root .. '/a/b/c', dir)
      assert.is_nil(basename)
    end)

    it('strips an existing .md extension from the rename target', function()
      local dir, basename = move_picker.parse_move_prompt('apps/next.md', root)
      assert.equals(root .. '/apps', dir)
      assert.equals('next.md', basename)
    end)

    it('treats a bare slash as shotfiles root + keep-name', function()
      local dir, basename = move_picker.parse_move_prompt('/', root)
      assert.equals(root, dir)
      assert.is_nil(basename)
    end)

    it('strips leading slashes and reparses', function()
      local dir, basename = move_picker.parse_move_prompt('/apps/next/', root)
      assert.equals(root .. '/apps/next', dir)
      assert.is_nil(basename)
    end)

    it('strips multiple trailing slashes', function()
      local dir, basename = move_picker.parse_move_prompt('apps/next//', root)
      assert.equals(root .. '/apps/next', dir)
      assert.is_nil(basename)
    end)

    it('matches the user spec case 1 (apps/next/domain)', function()
      local dir, basename = move_picker.parse_move_prompt('apps/next/domain', root)
      assert.equals(root .. '/apps/next', dir)
      assert.equals('domain.md', basename)
    end)

    it('matches the user spec case 2 (apps/next/ keeps source name)', function()
      local dir, basename = move_picker.parse_move_prompt('apps/next/', root)
      assert.equals(root .. '/apps/next', dir)
      assert.is_nil(basename)
    end)
  end)

  describe('move_file_to_path', function()
    local test_root = '/tmp/shooter_move_picker_test'
    local shotfiles_dir = test_root .. '/.hal/shooter/shotfiles'

    before_each(function()
      os.execute('rm -rf ' .. test_root)
      os.execute('mkdir -p ' .. shotfiles_dir)
    end)

    after_each(function()
      os.execute('rm -rf ' .. test_root)
    end)

    it('moves a file to a new folder, creating it', function()
      local src = shotfiles_dir .. '/next.md'
      utils.write_file(src, '# next\n\n## shot 1\nbody\n')

      local target = shotfiles_dir .. '/apps/next/next.md'
      local ok = move_picker.move_file_to_path(src, target, true)
      assert.is_true(ok)

      assert.equals(0, vim.fn.filereadable(src))
      assert.equals(1, vim.fn.filereadable(target))

      local content = utils.read_file(target)
      assert.truthy(content:find('^# apps/next/next\n'))
      assert.truthy(content:find('## shot 1'))
      assert.truthy(content:find('body'))
    end)

    it('renames a file when target basename differs from source', function()
      local src = shotfiles_dir .. '/next.md'
      utils.write_file(src, '# next\n')

      local target = shotfiles_dir .. '/apps/next/domain.md'
      local ok = move_picker.move_file_to_path(src, target, true)
      assert.is_true(ok)

      local content = utils.read_file(target)
      assert.truthy(content:find('^# apps/next/domain\n'))
    end)

    it('refuses to overwrite an existing target', function()
      local src = shotfiles_dir .. '/a.md'
      local dst = shotfiles_dir .. '/b.md'
      utils.write_file(src, '# a\n')
      utils.write_file(dst, '# b\n')

      local ok = move_picker.move_file_to_path(src, dst, true)
      assert.is_false(ok)

      -- Both files still exist, destination untouched
      assert.equals(1, vim.fn.filereadable(src))
      assert.equals('# b', utils.read_file(dst):match('^([^\n]+)'))
    end)

    it('no-ops when source equals target', function()
      local src = shotfiles_dir .. '/a.md'
      utils.write_file(src, '# a\n')

      local ok = move_picker.move_file_to_path(src, src, true)
      assert.is_false(ok)
      assert.equals(1, vim.fn.filereadable(src))
    end)

    it('returns false when source does not exist', function()
      local ok = move_picker.move_file_to_path(shotfiles_dir .. '/nope.md',
        shotfiles_dir .. '/apps/foo.md', true)
      assert.is_false(ok)
    end)
  end)
end)

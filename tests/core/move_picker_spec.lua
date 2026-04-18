-- Tests for shooter.core.move_picker
local move_picker = require('shooter.core.move_picker')
local utils = require('shooter.utils')

describe('shooter.core.move_picker', function()
  describe('parse_move_prompt', function()
    local root = '/repo/.hal/util/shooter/shotfiles'

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
    local shotfiles_dir = test_root .. '/.hal/util/shooter/shotfiles'

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

    it('deletes the source folder if it becomes empty', function()
      local src_dir = shotfiles_dir .. '/apps'
      os.execute('mkdir -p ' .. src_dir)
      local src = src_dir .. '/next.md'
      utils.write_file(src, '# apps/next\n')

      local ok = move_picker.move_file_to_path(src,
        shotfiles_dir .. '/archive/next.md', true)
      assert.is_true(ok)

      assert.equals(0, vim.fn.filereadable(src))
      assert.equals(0, vim.fn.isdirectory(src_dir))
    end)

    it('keeps the source folder if other files remain', function()
      local src_dir = shotfiles_dir .. '/apps'
      os.execute('mkdir -p ' .. src_dir)
      utils.write_file(src_dir .. '/next.md', '# apps/next\n')
      utils.write_file(src_dir .. '/other.md', '# apps/other\n')

      local ok = move_picker.move_file_to_path(
        src_dir .. '/next.md',
        shotfiles_dir .. '/archive/next.md',
        true
      )
      assert.is_true(ok)

      assert.equals(1, vim.fn.isdirectory(src_dir))
      assert.equals(1, vim.fn.filereadable(src_dir .. '/other.md'))
    end)

    it('walks up and deletes nested empty parents', function()
      local nested = shotfiles_dir .. '/a/b/c'
      os.execute('mkdir -p ' .. nested)
      utils.write_file(nested .. '/file.md', '# a/b/c/file\n')

      local ok = move_picker.move_file_to_path(
        nested .. '/file.md',
        shotfiles_dir .. '/archive/file.md',
        true
      )
      assert.is_true(ok)

      assert.equals(0, vim.fn.isdirectory(nested))
      assert.equals(0, vim.fn.isdirectory(shotfiles_dir .. '/a/b'))
      assert.equals(0, vim.fn.isdirectory(shotfiles_dir .. '/a'))
      assert.equals(1, vim.fn.isdirectory(shotfiles_dir))
    end)

    it('stops walking up when hitting a non-empty ancestor', function()
      local src_dir = shotfiles_dir .. '/keep/inner'
      os.execute('mkdir -p ' .. src_dir)
      utils.write_file(shotfiles_dir .. '/keep/sibling.md', '# keep/sibling\n')
      utils.write_file(src_dir .. '/file.md', '# keep/inner/file\n')

      local ok = move_picker.move_file_to_path(
        src_dir .. '/file.md',
        shotfiles_dir .. '/archive/file.md',
        true
      )
      assert.is_true(ok)

      assert.equals(0, vim.fn.isdirectory(src_dir))
      assert.equals(1, vim.fn.isdirectory(shotfiles_dir .. '/keep'))
      assert.equals(1, vim.fn.filereadable(shotfiles_dir .. '/keep/sibling.md'))
    end)

    it('never deletes the shotfiles root itself', function()
      local src = shotfiles_dir .. '/foo.md'
      utils.write_file(src, '# foo\n')

      local ok = move_picker.move_file_to_path(src,
        shotfiles_dir .. '/sub/foo.md', true)
      assert.is_true(ok)
      assert.equals(1, vim.fn.isdirectory(shotfiles_dir))
    end)

    it('leaves source folders outside a shotfiles tree alone', function()
      local outside_dir = test_root .. '/not_shotfiles'
      os.execute('mkdir -p ' .. outside_dir)
      local src = outside_dir .. '/file.md'
      utils.write_file(src, '# file\n')

      local ok = move_picker.move_file_to_path(src,
        shotfiles_dir .. '/file.md', true)
      assert.is_true(ok)

      -- The outside dir is now empty but must NOT be deleted by our cleanup.
      assert.equals(1, vim.fn.isdirectory(outside_dir))
    end)
  end)

  describe('collect_shotfile_folders', function()
    local test_dir = '/tmp/shooter_collect_folders_test'

    before_each(function()
      os.execute('rm -rf ' .. test_dir)
      os.execute('mkdir -p ' .. test_dir)
    end)

    after_each(function()
      os.execute('rm -rf ' .. test_dir)
    end)

    local function displays(folders)
      local out = {}
      for _, f in ipairs(folders) do table.insert(out, f.display) end
      return out
    end

    it('returns just (root) for an empty directory', function()
      local folders = move_picker.collect_shotfile_folders(test_dir)
      assert.equals(1, #folders)
      assert.equals('(root)', folders[1].display)
      assert.equals(test_dir, folders[1].path)
    end)

    it('returns just (root) when the directory does not exist', function()
      local missing = '/tmp/shooter_collect_missing_' .. os.time() .. '_' .. math.random(100000)
      local folders = move_picker.collect_shotfile_folders(missing)
      assert.equals(1, #folders)
      assert.equals('(root)', folders[1].display)
    end)

    it('lists first-level subdirs', function()
      os.execute('mkdir -p ' .. test_dir .. '/archive ' .. test_dir .. '/domains')
      assert.are.same(
        { '(root)', 'archive', 'domains' },
        displays(move_picker.collect_shotfile_folders(test_dir))
      )
    end)

    it('recurses into all levels of subdirs', function()
      os.execute('mkdir -p ' .. test_dir .. '/apps/next/domain')
      os.execute('mkdir -p ' .. test_dir .. '/apps/other')
      os.execute('mkdir -p ' .. test_dir .. '/archive')
      assert.are.same(
        { '(root)', 'apps', 'apps/next', 'apps/next/domain', 'apps/other', 'archive' },
        displays(move_picker.collect_shotfile_folders(test_dir))
      )
    end)

    it('exposes absolute paths alongside relative displays', function()
      os.execute('mkdir -p ' .. test_dir .. '/a/b')
      local folders = move_picker.collect_shotfile_folders(test_dir)
      local by_display = {}
      for _, f in ipairs(folders) do by_display[f.display] = f.path end
      assert.equals(test_dir, by_display['(root)'])
      assert.equals(test_dir .. '/a', by_display['a'])
      assert.equals(test_dir .. '/a/b', by_display['a/b'])
    end)

    it('ignores files at any depth', function()
      os.execute('mkdir -p ' .. test_dir .. '/apps')
      os.execute('touch ' .. test_dir .. '/root.md ' .. test_dir .. '/apps/leaf.md')
      assert.are.same(
        { '(root)', 'apps' },
        displays(move_picker.collect_shotfile_folders(test_dir))
      )
    end)
  end)
end)

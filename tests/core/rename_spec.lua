-- Tests for shooter.core.rename
local rename = require('shooter.core.rename')
local utils = require('shooter.utils')

describe('shooter.core.rename', function()
  local test_dir = '/tmp/shooter_rename_test'

  before_each(function()
    os.execute('mkdir -p ' .. test_dir)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_dir)
  end)

  describe('perform_rename', function()
    it('should rename file successfully', function()
      local old_path = test_dir .. '/old-name.md'
      utils.write_file(old_path, '# Test content')

      local success, err, info = rename.perform_rename(old_path, 'new-name.md')

      assert.is_true(success)
      assert.is_nil(err)
      assert.equals(test_dir .. '/new-name.md', info.new_path)
      assert.equals(1, vim.fn.filereadable(test_dir .. '/new-name.md'))
      assert.equals(0, vim.fn.filereadable(old_path))
    end)

    it('should fail if target already exists', function()
      local old_path = test_dir .. '/old-name.md'
      local existing_path = test_dir .. '/existing.md'
      utils.write_file(old_path, '# Test')
      utils.write_file(existing_path, '# Existing')

      local success, err = rename.perform_rename(old_path, 'existing.md')

      assert.is_false(success)
      assert.truthy(err:find('already exists'))
    end)

    it('should fail if name unchanged', function()
      local old_path = test_dir .. '/same-name.md'
      utils.write_file(old_path, '# Test')

      local success, err = rename.perform_rename(old_path, 'same-name.md')

      assert.is_false(success)
      assert.truthy(err:find('unchanged'))
    end)

    it('should fail with nil parameters', function()
      local success, err = rename.perform_rename(nil, 'name.md')
      assert.is_false(success)
      assert.truthy(err:find('Invalid'))
    end)
  end)
end)

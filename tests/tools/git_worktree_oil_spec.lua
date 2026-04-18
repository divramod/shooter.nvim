local gwo = require('shooter.tools.git_worktree_oil')

describe('shooter.tools.git_worktree_oil', function()
  describe('compute_target', function()
    local current_root = '/tmp/shooter_gwo_test/wt/1'
    local target_root = '/tmp/shooter_gwo_test/wt/2'

    before_each(function()
      os.execute('rm -rf /tmp/shooter_gwo_test')
      os.execute('mkdir -p ' .. current_root .. '/lua/shooter/core')
      os.execute('mkdir -p ' .. target_root .. '/lua/shooter/core')
      os.execute('touch ' .. current_root .. '/lua/shooter/core/foo.lua')
      os.execute('touch ' .. target_root .. '/lua/shooter/core/foo.lua')
      os.execute('mkdir -p ' .. current_root .. '/only_here')
      os.execute('touch ' .. current_root .. '/only_here/missing.lua')
    end)

    after_each(function()
      os.execute('rm -rf /tmp/shooter_gwo_test')
    end)

    it('returns the parallel file when it exists', function()
      local current_file = current_root .. '/lua/shooter/core/foo.lua'
      local tf, td, exists, err = gwo.compute_target(current_file, current_root, target_root)
      assert.is_nil(err)
      assert.equals(target_root .. '/lua/shooter/core/foo.lua', tf)
      assert.equals(target_root .. '/lua/shooter/core', td)
      assert.is_true(exists)
    end)

    it('returns the parallel dir and file_exists=false when file missing', function()
      local current_file = current_root .. '/only_here/missing.lua'
      local tf, td, exists, err = gwo.compute_target(current_file, current_root, target_root)
      assert.is_nil(err)
      assert.equals(target_root .. '/only_here/missing.lua', tf)
      assert.equals(target_root .. '/only_here', td)
      assert.is_false(exists)
    end)

    it('handles current_file being the worktree root directory', function()
      local tf, td, exists, err = gwo.compute_target(current_root, current_root, target_root)
      assert.is_nil(err)
      assert.equals(target_root, tf)
      assert.equals(target_root, td)
      assert.is_false(exists)
    end)

    it('errors when current_file is outside the current worktree', function()
      local tf, _, _, err = gwo.compute_target('/etc/passwd', current_root, target_root)
      assert.is_nil(tf)
      assert.truthy(err)
    end)
  end)
end)

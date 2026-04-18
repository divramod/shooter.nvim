-- Tests for shooter.core.repos
local repos = require('shooter.core.repos')
local utils = require('shooter.utils')

describe('shooter.core.repos', function()
  local test_repo = '/tmp/shooter_repos_test'

  before_each(function()
    os.execute('rm -rf ' .. test_repo)
    os.execute('mkdir -p ' .. test_repo)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_repo)
  end)

  describe('create_file_in_repo', function()
    it('creates file in .hal/util/shooter/shotfiles with canonical title', function()
      local path = repos.create_file_in_repo(test_repo, 'My Feature')
      assert.is_truthy(path)
      assert.is_truthy(path:find(test_repo .. '/.hal/util/shooter/shotfiles/my%-feature%.md$'))
      local content = utils.read_file(path)
      assert.equals('# my-feature', content:match('^([^\n]+)'))
    end)

    it('writes title as filename without .md extension', function()
      local path = repos.create_file_in_repo(test_repo, 'Shot File')
      local content = utils.read_file(path)
      assert.is_nil(content:match('^# .-%.md'))
    end)
  end)
end)

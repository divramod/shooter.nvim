-- Test suite for shooter.core.shots module
local shots = require('shooter.core.shots')

describe('shots module', function()
  before_each(function()
    -- Set up test environment
  end)

  after_each(function()
    -- Clean up
  end)

  describe('find_current_shot', function()
    it('finds shot at cursor position', function()
      -- Create test buffer with shots
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test File',
        '',
        '## shot 1',
        'First shot content',
        '',
        '## shot 2',
        'Second shot content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Test finding shot 1
      local start, finish, header = shots.find_current_shot(bufnr, 3)
      assert.are.equal(3, start)
      assert.are.equal(4, finish)
      assert.are.equal(3, header)
    end)

    it('returns nil when no shot found', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {'# No shots here', 'Just text'}
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local start, finish, header = shots.find_current_shot(bufnr, 1)
      assert.is_nil(start)
      assert.is_nil(finish)
      assert.is_nil(header)
    end)
  end)

  describe('mark_shot_executed', function()
    it('marks shot with x and timestamp', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {'## shot 1', 'content'}
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      shots.mark_shot_executed(bufnr, 1)

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
      assert.is_truthy(result:match('^## x shot 1'))
      assert.is_truthy(result:match('%d%d%d%d%d%d%d%d_%d%d%d%d'))
    end)

    it('updates timestamp on already executed shot', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {'## x shot 1 (20260120_1200)', 'content'}
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      shots.mark_shot_executed(bufnr, 1)

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
      assert.is_truthy(result:match('^## x shot 1'))
      -- Should have new timestamp, not old one
      assert.is_falsy(result:match('20260120_1200'))
    end)
  end)

  describe('find_open_shots', function()
    it('returns only non-executed shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test',
        '## shot 1',
        'content',
        '## x shot 2',
        'done',
        '## shot 3',
        'open',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local open_shots = shots.find_open_shots(bufnr)
      assert.are.equal(2, #open_shots)
      assert.are.equal(2, open_shots[1].header_line)  -- shot 1
      assert.are.equal(6, open_shots[2].header_line)  -- shot 3
    end)

    it('returns empty table when all shots executed', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test',
        '## x shot 1',
        'done',
        '## x shot 2',
        'also done',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local open_shots = shots.find_open_shots(bufnr)
      assert.are.equal(0, #open_shots)
    end)
  end)

  describe('parse_shot_header', function()
    it('extracts shot number from header', function()
      assert.are.equal('1', shots.parse_shot_header('## shot 1'))
      assert.are.equal('42', shots.parse_shot_header('## shot 42'))
      assert.are.equal('5', shots.parse_shot_header('## x shot 5'))
    end)

    it('returns ? for invalid headers', function()
      assert.are.equal('?', shots.parse_shot_header('## no number here'))
      assert.are.equal('?', shots.parse_shot_header('not a header'))
    end)
  end)

  describe('get_shot_content', function()
    it('returns content without header', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '## shot 1',
        'Line 1 of content',
        'Line 2 of content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local content = shots.get_shot_content(bufnr, 1, 3)
      assert.are.equal('Line 1 of content\nLine 2 of content', content)
    end)

    it('trims leading and trailing empty lines', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '## shot 1',
        '',
        'Content',
        '',
        '',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local content = shots.get_shot_content(bufnr, 1, 5)
      assert.are.equal('Content', content)
    end)
  end)
end)

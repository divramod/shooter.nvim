-- Tests for token counter tool
local token_counter = require('shooter.tools.token_counter')

describe('token_counter', function()
  describe('count_tokens', function()
    it('returns error for non-existent file', function()
      local count, err = token_counter.count_tokens('/nonexistent/file.txt')
      assert.is_nil(count)
      assert.is_not_nil(err)
      assert.matches('not readable', err)
    end)

    it('returns error for empty filepath', function()
      local count, err = token_counter.count_tokens('')
      assert.is_nil(count)
      assert.is_not_nil(err)
      assert.matches('No file', err)
    end)

    -- Note: These tests require ttok to be installed
    -- They will be skipped if ttok is not available
    describe('with ttok installed', function()
      local ttok_available = vim.fn.executable('ttok') == 1

      it('counts tokens in a test file', function()
        if not ttok_available then
          pending('ttok not installed')
          return
        end

        -- Create a temp file with known content
        local tmp_file = vim.fn.tempname() .. '.txt'
        local f = io.open(tmp_file, 'w')
        f:write('Hello world this is a test')
        f:close()

        local count, err = token_counter.count_tokens(tmp_file)

        -- Clean up
        os.remove(tmp_file)

        assert.is_nil(err)
        assert.is_number(count)
        assert.is_true(count > 0) -- Should have at least some tokens
      end)
    end)
  end)
end)

-- Tests for response viewer (OpenCode storage)
local opencode = require('shooter.tools.response_viewer.opencode')
local response_viewer = require('shooter.tools.response_viewer')

describe('response viewer (opencode)', function()
  local original_xdg = os.getenv('XDG_DATA_HOME')

  local function write_json(path, tbl)
    vim.fn.writefile({ vim.fn.json_encode(tbl) }, path)
  end

  local function setup_storage(base, shot_ref, response_text)
    local storage = base .. '/opencode/storage'
    local message_dir = storage .. '/message/ses_test'
    local part_dir_user = storage .. '/part/msg_user'
    local part_dir_assistant = storage .. '/part/msg_assistant'

    vim.fn.mkdir(message_dir, 'p')
    vim.fn.mkdir(part_dir_user, 'p')
    vim.fn.mkdir(part_dir_assistant, 'p')

    write_json(message_dir .. '/msg_user.json', {
      id = 'msg_user',
      sessionID = 'ses_test',
      role = 'user',
      time = { created = 1 },
    })
    write_json(message_dir .. '/msg_assistant.json', {
      id = 'msg_assistant',
      sessionID = 'ses_test',
      role = 'assistant',
      parentID = 'msg_user',
      time = { created = 2 },
    })

    write_json(part_dir_user .. '/part_user.json', {
      id = 'part_user',
      sessionID = 'ses_test',
      messageID = 'msg_user',
      type = 'text',
      text = '@/' .. shot_ref .. '.md',
    })
    write_json(part_dir_assistant .. '/part_text.json', {
      id = 'part_text',
      sessionID = 'ses_test',
      messageID = 'msg_assistant',
      type = 'text',
      text = response_text,
    })
    write_json(part_dir_assistant .. '/part_tool.json', {
      id = 'part_tool',
      sessionID = 'ses_test',
      messageID = 'msg_assistant',
      type = 'tool',
      tool = 'read',
    })
  end

  after_each(function()
    if original_xdg then
      vim.fn.setenv('XDG_DATA_HOME', original_xdg)
    else
      vim.fn.setenv('XDG_DATA_HOME', '')
    end
  end)

  it('finds response text and tool calls from storage', function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, 'p')
    vim.fn.setenv('XDG_DATA_HOME', temp_dir)

    setup_storage(temp_dir, 'shot-1-20260204_010203', 'hello from opencode')

    local response_text, tool_calls = opencode.find_response('shot%-1%-20260204_010203')
    vim.fn.delete(temp_dir, 'rf')

    assert.is_truthy(response_text:match('hello from opencode'))
    assert.are.equal('read', tool_calls[1])
  end)

  it('views response from opencode storage', function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, 'p')
    vim.fn.setenv('XDG_DATA_HOME', temp_dir)

    setup_storage(temp_dir, 'shot-1-20260204_010203', 'response body')

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      '# title',
      '',
      '## x shot 1 (2026-02-04 01:02:03) @shot-1-20260204_010203',
      'body',
    })
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })

    response_viewer.view_response()

    local resp_bufnr = vim.api.nvim_get_current_buf()
    local resp_name = vim.api.nvim_buf_get_name(resp_bufnr)
    local resp_lines = vim.api.nvim_buf_get_lines(resp_bufnr, 0, -1, false)

    vim.fn.delete(temp_dir, 'rf')
    vim.cmd('only')

    assert.is_truthy(resp_name:match('Shot 1 Response'))
    assert.is_truthy(table.concat(resp_lines, '\n'):match('response body'))
  end)
end)

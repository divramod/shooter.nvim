-- Public-surface contract for shooter.core.shot_actions.
-- Locks the 17-fn surface ahead of the Phase 002 T007 split. Behavioral
-- coverage of the heavyweight functions (yank_shot, toggle_shot_done,
-- delete_last_shot, navigation, undo) lives in shot_actions_spec.lua.
-- Coverage gap on shot_actions (~47%) is documented in baseline.md and
-- escalated to Phase 005 T002 — many functions need realistic shotfile
-- buffer state that's expensive to set up per-test.

local sa = require('shooter.core.shot_actions')

describe('shooter.core.shot_actions public surface', function()
  local expected = {
    'create_new_shot',
    'create_new_shot_with_whisper',
    'delete_last_shot',
    'goto_next_open_shot',
    'goto_prev_open_shot',
    'toggle_shot_done',
    'goto_latest_sent_shot',
    'goto_prev_sent_shot',
    'goto_next_sent_shot',
    'undo_latest_sent_shot',
    'yank_shot',
    'extract_subtask',
    'extract_line',
    'file_stats',
    'create_shot_from_file',
    'create_shot_from_claude',
  }
  for _, fn in ipairs(expected) do
    it('exports M.' .. fn, function()
      assert.is_function(sa[fn])
    end)
  end
end)

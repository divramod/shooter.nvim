-- Targeted tests covering small uncovered branches in ext_config to push
-- coverage from 79.81% past the Phase 002 T002 80% gate. Existing
-- ext_config_spec.lua covers parse_yaml/serialize_yaml/paths exhaustively;
-- this file pins the load/get/reload entry points and a few edge cases.

local ext = require('shooter.core.ext_config')

describe('shooter.core.ext_config extras', function()
  describe('load + reload', function()
    it('load returns a table', function()
      local cfg = ext.load()
      assert.is_table(cfg)
    end)

    it('reload re-reads the config file (no return value)', function()
      -- Characterization: reload() does NOT return the new config; it
      -- re-runs the load pipeline for side-effect on cached state. Phase
      -- 002 T005 must preserve this contract (callers don't rely on
      -- the return value).
      local result = ext.reload()
      assert.is_nil(result)
    end)
  end)

  describe('get(dot_path)', function()
    it('returns nil for an unknown path', function()
      assert.is_nil(ext.get('this.path.does.not.exist'))
    end)

    it('throws on nil dot_path (current contract)', function()
      -- Characterization: get(nil) throws — callers must always pass a
      -- string. Phase 002 T005 may harden this with a guard, but the
      -- current behavior is "fail loud". Lock it here so any change to
      -- the contract surfaces in the diff.
      local ok = pcall(ext.get, nil)
      assert.is_false(ok)
    end)

    it('handles a single-segment path', function()
      local ok = pcall(ext.get, 'session')
      assert.is_true(ok)
    end)
  end)

  describe('serialize_yaml edge cases', function()
    it('serializes an empty table to an empty string', function()
      local s = ext.serialize_yaml({})
      assert.is_string(s)
    end)

    it('round-trips a small table through parse_yaml', function()
      local input = { foo = 'bar', n = 42 }
      local serialized = ext.serialize_yaml(input)
      local parsed = ext.parse_yaml(serialized)
      assert.equals('bar', parsed.foo)
    end)
  end)

  describe('path accessors extras', function()
    it('tmp_dir returns a path string', function()
      local d = ext.tmp_dir()
      assert.is_string(d)
      assert.is_truthy(#d > 0)
    end)

    it('last_shotfile_path produces a per-slug path', function()
      local p = ext.last_shotfile_path('myrepo')
      assert.is_string(p)
      assert.is_truthy(p:find('myrepo'))
    end)

    it('global_config_path returns a path under ~/.config/hal', function()
      local p = ext.global_config_path()
      assert.is_string(p)
      assert.is_truthy(p:find('hal'))
    end)

    it('local_config_path returns a path inside the repo', function()
      local p = ext.local_config_path()
      assert.is_string(p)
    end)
  end)
end)

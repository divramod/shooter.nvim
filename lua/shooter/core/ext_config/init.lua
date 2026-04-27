-- shooter.core.ext_config public surface — re-exports the YAML-config API.
-- No logic; every function lives in a sibling sub-module.

local paths = require('shooter.core.ext_config.paths')
local yaml = require('shooter.core.ext_config.yaml')
local load_mod = require('shooter.core.ext_config.load')
local fix = require('shooter.core.ext_config.fix')

local M = {}

-- schema
M.DEFAULTS = load_mod.DEFAULTS

-- paths
M.base_dir = paths.base_dir
M.sessions_dir = paths.sessions_dir
M.bullets_dir = paths.bullets_dir
M.tmp_dir = paths.tmp_dir
M.filter_state_path = paths.filter_state_path
M.last_shotfile_path = paths.last_shotfile_path
M.global_config_path = paths.global_config_path
M.local_config_path = paths.local_config_path

-- yaml
M.parse_yaml = yaml.parse_yaml
M.serialize_yaml = yaml.serialize_yaml

-- load
M.ensure_global_config = load_mod.ensure_global_config
M.ensure_local_config = load_mod.ensure_local_config
M.load = load_mod.load
M.get = load_mod.get
M.reload = load_mod.reload

-- fix
M.fix_config = fix.fix_config
M.fix_config_buffer = fix.fix_config_buffer

return M

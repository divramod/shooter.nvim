-- Sound playback for shooter.nvim
-- Delegates to `hal shooter sound play` for actual playback

local config = require('shooter.config')
local utils = require('shooter.utils')

local M = {}

-- Play sound via hal shooter sound play (async — fire and forget)
function M.play()
  if not config.get('sound.enabled') then
    return
  end

  local sound_file = config.get('sound.file')
  if not sound_file or sound_file == '' then
    return
  end

  local volume = config.get('sound.volume') or 0.5
  -- Fire and forget — hal spawns afplay/aplay in background
  vim.fn.jobstart(
    string.format('hal shooter sound play --file %s --volume %s', vim.fn.shellescape(sound_file), volume),
    { detach = true, on_stderr = function() end }
  )
end

-- Play sound with custom file (one-off)
function M.play_file(filepath, volume)
  if not filepath or filepath == '' then
    return
  end
  volume = volume or 0.5
  vim.fn.jobstart(
    string.format('hal shooter sound play --file %s --volume %s', vim.fn.shellescape(filepath), volume),
    { detach = true, on_stderr = function() end }
  )
end

-- Test sound
function M.test()
  if not config.get('sound.enabled') then
    utils.echo('Sound is disabled. Enable with sound.enabled = true')
    return
  end

  local sound_file = config.get('sound.file')
  if not sound_file or sound_file == '' then
    utils.echo('No sound file configured')
    return
  end

  M.play()
  utils.echo('Playing: ' .. sound_file .. ' (volume: ' .. (config.get('sound.volume') or 0.5) .. ')')
end

return M

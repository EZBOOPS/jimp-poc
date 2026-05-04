local tracker = require 'core.tracker'
local world   = require 'core.world'

local TEMIS_WAYPOINT = 0x1CE51E  -- Temis waypoint SNO

local teleported_this_cycle = false

local task = {
    name   = 'teleport_to_dungeon',
    status = 'idle',
}

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    teleported_this_cycle = false
end

task.shouldExecute = function()
    if tracker.boss_dead then return false end
    if world.is_inside() then return false end
    if teleported_this_cycle then return false end
    return true
end

task.Execute = function()
    task.status          = 'teleporting to Temis'
    teleported_this_cycle = true
    teleport_to_waypoint(TEMIS_WAYPOINT)
    console.print('[GemFarmer] Teleporting to Temis waypoint')
end

return task

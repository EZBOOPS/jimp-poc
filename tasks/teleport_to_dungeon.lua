local tracker = require 'core.tracker'
local world   = require 'core.world'

local TEMIS_WAYPOINT    = 0x1CE51E  -- Temis waypoint SNO
local LOAD_WAIT         = 8.0       -- seconds to wait for zone load before rechecking

local teleport_time     = -1
local confirmed_at_temis = false

local task = {
    name   = 'teleport_to_dungeon',
    status = 'idle',
}

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    teleport_time        = -1
    confirmed_at_temis   = false
end

task.shouldExecute = function()
    if tracker.boss_dead then return false end
    if world.is_inside() then return false end
    if confirmed_at_temis then return false end  -- already landed this cycle

    local now = get_time_since_inject()

    -- Within the loading window — check if we've arrived yet
    if teleport_time > 0 and (now - teleport_time) < LOAD_WAIT then
        if world.is_outside() then
            confirmed_at_temis = true
            console.print('[GemFarmer] Confirmed at Temis — handing off to walk task')
        else
            task.status = string.format('waiting for Temis load (%.1fs)', LOAD_WAIT - (now - teleport_time))
        end
        return false
    end

    -- Haven't teleported yet, or load window expired without confirming → teleport
    return true
end

task.Execute = function()
    task.status   = 'teleporting to Temis'
    teleport_time = get_time_since_inject()
    teleport_to_waypoint(TEMIS_WAYPOINT)
    console.print('[GemFarmer] Teleporting to Temis waypoint')
end

return task

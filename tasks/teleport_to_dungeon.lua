local tracker = require 'core.tracker'
local world   = require 'core.world'
local paths   = require 'core.paths'

local TEMIS_WAYPOINT = 0x1CE51E  -- Temis waypoint SNO
local ENTRANCE_RANGE = 10.0      -- metres — within this = already close enough, no teleport needed

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

local function entrance_pos()
    local ap = paths.approach
    if ap and #ap > 0 then return ap[#ap] end
    return nil
end

task.shouldExecute = function()
    if tracker.boss_dead then return false end
    if world.is_inside() then return false end
    if teleported_this_cycle then return false end  -- only teleport once per cycle

    local ep = entrance_pos()
    if not ep then return false end
    local player = get_local_player()
    if not player then return false end

    -- Already near the entrance — no need to teleport
    return player:get_position():dist_to(ep) >= ENTRANCE_RANGE
end

task.Execute = function()
    task.status          = 'teleporting to Temis'
    teleported_this_cycle = true
    teleport_to_waypoint(TEMIS_WAYPOINT)
    console.print('[GemFarmer] Teleporting to Temis waypoint')
end

return task

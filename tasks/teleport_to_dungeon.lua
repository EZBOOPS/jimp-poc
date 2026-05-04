local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local paths    = require 'core.paths'

local WAYPOINT_ID = 4156639130   -- Seer's Reach waypoint SNO

local task = {
    name   = 'teleport_to_dungeon',
    status = 'idle',
}

-- Returns the last point of the approach path (= dungeon entrance), or nil.
local function entrance_pos()
    local ap = paths.approach
    if ap and #ap > 0 then return ap[#ap] end
    return nil
end

task.shouldExecute = function()
    if tracker.inside_dungeon then return false end
    if tracker.exited_dungeon then return false end

    -- No approach path recorded yet — cannot navigate, do nothing
    local ep = entrance_pos()
    if not ep then return false end

    -- Already near the entrance — walk_to_dungeon / enter_dungeon will handle it
    local player = get_local_player()
    if not player then return false end
    if player:get_position():dist_to(ep) < 60 then return false end

    -- Cooldown between teleport attempts
    local now = get_time_since_inject()
    if tracker.teleport_time > 0 and now - tracker.teleport_time < tracker.teleport_cooldown then
        return false
    end

    return true
end

task.Execute = function()
    task.status = 'teleporting'
    tracker.teleport_time = get_time_since_inject()
    teleport_to_waypoint(WAYPOINT_ID)
    console.print('[GemFarmer] Teleporting to Seers Reach waypoint')
end

return task

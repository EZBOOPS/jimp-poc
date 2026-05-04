local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local paths    = require 'core.paths'

local DONE_THRESHOLD = 10.0   -- metres — hand off to enter_dungeon when this close to last waypoint

local task = {
    name   = 'walk_to_dungeon',
    status = 'idle',
}

local function approach()
    return paths.approach
end

local function last_wp()
    local ap = approach()
    if ap and #ap > 0 then return ap[#ap] end
    return nil
end

task.shouldExecute = function()
    if tracker.inside_dungeon then return false end
    if tracker.exited_dungeon then return false end
    local ap = approach()
    if not ap or #ap == 0 then return false end   -- no approach path recorded yet
    local player = get_local_player()
    if not player then return false end
    local dest = last_wp()
    return player:get_position():dist_to(dest) > DONE_THRESHOLD
end

task.Execute = function()
    local ap = approach()
    if not ap or #ap == 0 then return end
    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()

    -- Advance waypoint index while within threshold
    while tracker.approach_index < #ap do
        if player_pos:dist_to(ap[tracker.approach_index]) <= settings.wp_threshold then
            tracker.approach_index = tracker.approach_index + 1
        else
            break
        end
    end

    local target = ap[tracker.approach_index]
    local dist   = player_pos:dist_to(ap[#ap])
    task.status  = string.format('walking to dungeon (%d/%d, %.1fm left)', tracker.approach_index, #ap, dist)
    pathfinder.request_move(target)
end

return task

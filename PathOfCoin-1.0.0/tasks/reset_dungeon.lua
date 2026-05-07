local tracker  = require 'core.tracker'
local settings = require 'core.settings'
local world    = require 'core.world'

local RESET_POS   = vec3:new(108.5811, 47.0459, 0.0977)
local PORTAL_NAME = 'Portal_Town'
local PORTAL_RANGE = 15.0

local task = {
    name   = 'reset_dungeon',
    status = 'idle',
    step   = 0,
    step_t = -1,
}

local function set_step(s)
    task.step  = s
    task.step_t = get_time_since_inject()
end

local function waited(secs)
    return (get_time_since_inject() - task.step_t) >= secs
end

local function find_portal(player_pos)
    for _, actor in ipairs(actors_manager.get_all_actors()) do
        local ok, name = pcall(function() return actor:get_skin_name() end)
        if ok and name and name:find(PORTAL_NAME) then
            local dist = actor:get_position():dist_to(player_pos)
            if dist <= PORTAL_RANGE then
                return actor, dist
            end
        end
    end
    return nil, nil
end

task.shouldExecute = function()
    if not world.is_in_dungeon() then return false end
    if not tracker.route_done then return false end
    if not tracker.boss_chest_done then return false end
    if not tracker.left_party then return false end
    return task.step > 0 or tracker.reset_time >= 0
end

task.start = function()
    if task.step == 0 then
        set_step(1)
        tracker.reset_time = get_time_since_inject()
    end
end

task.Execute = function()
    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()

    if task.step == 1 then
        task.status = 'looking for exit portal'
        local portal, dist = find_portal(player_pos)
        if portal then
            if dist > 3.0 then
                pathfinder.request_move(portal:get_position())
            else
                interact_object(portal)
                set_step(2)
            end
        elseif waited(settings.reset_wait or 10) then
            task.status = 'portal timeout — resetting tracker'
            tracker.reset_run()
            task.step = 0
        end
    elseif task.step == 2 then
        task.status = 'waiting for world transition'
        if not world.is_in_dungeon() then
            tracker.reset_run()
            task.step = 0
        elseif waited(15) then
            tracker.reset_run()
            task.step = 0
        end
    end
end

return task

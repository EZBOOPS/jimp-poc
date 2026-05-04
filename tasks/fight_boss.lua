local settings     = require 'core.settings'
local tracker      = require 'core.tracker'
local world        = require 'core.world'

local plugin_label = 'gem_farmer'
local STAY_RANGE   = 15.0

local task = {
    name   = 'fight_boss',
    status = 'idle',
}

local function is_butcher(actor)
    local name = actor:get_skin_name()
    return name and name:lower():find('butcher') ~= nil
end

local function find_boss_actor(player_pos)
    for _, actor in ipairs(actors_manager.get_enemy_actors()) do
        if actor:is_boss() and not is_butcher(actor) and actor:get_position():dist_to(player_pos) < settings.boss_range then
            return actor
        end
    end
    return nil
end

task.shouldExecute = function()
    return world.is_inside() and tracker.boss_found and not tracker.boss_dead
end

task.Execute = function()
    -- Keep Batmobile paused while we fight
    if BatmobilePlugin then
        BatmobilePlugin.pause(plugin_label)
        BatmobilePlugin.update(plugin_label)
    end

    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()

    local boss = find_boss_actor(player_pos)

    if boss then
        tracker.boss_last_pos = boss:get_position()

        if boss:is_dead() then
            tracker.boss_dead       = true
            tracker.loot_start_time = get_time_since_inject()
            task.status = 'boss dead — waiting for loot'
            console.print('[GemFarmer] Boss killed — waiting ' .. settings.loot_wait .. 's for loot')
            return
        end

        local dist = player_pos:dist_to(boss:get_position())
        if dist > STAY_RANGE then
            task.status = 'moving into range'
            pathfinder.request_move(boss:get_position())
        else
            task.status = 'in combat'
        end

    else
        -- Actor gone from the list — assume dead
        if tracker.boss_last_pos and player_pos:dist_to(tracker.boss_last_pos) < settings.boss_range then
            tracker.boss_dead       = true
            tracker.loot_start_time = get_time_since_inject()
            task.status = 'boss gone — waiting for loot'
            console.print('[GemFarmer] Boss actor gone — assuming dead')
        else
            task.status = 'returning to boss area'
            if tracker.boss_last_pos then
                pathfinder.request_move(tracker.boss_last_pos)
            end
        end
    end
end

return task

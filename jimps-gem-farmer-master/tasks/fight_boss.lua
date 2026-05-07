local settings     = require 'core.settings'
local tracker      = require 'core.tracker'
local world        = require 'core.world'
local stats        = require 'core.stats'

local plugin_label = 'gem_farmer'
local STAY_RANGE   = 15.0

local UR_ENABLED_HASH = get_hash('magoogles_universal_rotation_enabled')
local function set_ur_enabled(state)
    local el = checkbox:new(state, UR_ENABLED_HASH)
    el:set(state)
end

local BM_MOVEMENT_KEYS = {
    'use_evade', 'use_teleport', 'use_teleport_enchanted', 'use_dash',
    'use_soar', 'use_hunter', 'use_leap', 'use_charge',
    'use_advance', 'use_falling_star', 'use_aoj',
}

local function set_bm_movement(state)
    for _, key in ipairs(BM_MOVEMENT_KEYS) do
        local el = checkbox:new(state, get_hash('batmobile_' .. key))
        el:set(state)
    end
end

local task = {
    name              = 'fight_boss',
    status            = 'idle',
    movement_disabled = false,
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

local function on_boss_dead()
    set_bm_movement(true)
    task.movement_disabled = false
    if settings.ur_boss_only then set_ur_enabled(false) end
    _G.EXTERNAL_ROTATION_TARGET = nil
end

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    if task.movement_disabled then
        set_bm_movement(true)
        task.movement_disabled = false
    end
    _G.EXTERNAL_ROTATION_TARGET = nil
end

task.shouldExecute = function()
    return not world.is_outside() and tracker.boss_found and not tracker.boss_dead
end

task.Execute = function()
    if BatmobilePlugin == nil then return end

    -- On first entry: disable movement skills, enable UR if boss-only mode on
    if not task.movement_disabled then
        set_bm_movement(false)
        task.movement_disabled = true
        if settings.ur_boss_only then set_ur_enabled(true) end
        console.print('[GemFarmer] Boss fight started — movement skills disabled')
    end

    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()

    local boss = find_boss_actor(player_pos)

    if boss then
        tracker.boss_last_pos = boss:get_position()
        _G.EXTERNAL_ROTATION_TARGET = boss

        if boss:is_dead() then
            tracker.boss_dead       = true
            tracker.loot_start_time = get_time_since_inject()
            stats.record_kill(tracker.enter_time)
            on_boss_dead()
            task.status = 'boss dead — waiting for loot'
            console.print('[GemFarmer] Boss killed — movement skills restored')
            return
        end

        local dist = player_pos:dist_to(boss:get_position())
        if dist > STAY_RANGE then
            task.status = string.format('running to boss (%.1fm)', dist)
            BatmobilePlugin.set_target(plugin_label, boss:get_position(), false)
            BatmobilePlugin.resume(plugin_label)
            BatmobilePlugin.update(plugin_label)
            BatmobilePlugin.move(plugin_label)
        else
            BatmobilePlugin.pause(plugin_label)
            task.status = 'in combat'
        end

    else
        _G.EXTERNAL_ROTATION_TARGET = nil
        -- Actor gone from the list — assume dead
        if tracker.boss_last_pos and player_pos:dist_to(tracker.boss_last_pos) < settings.boss_range then
            tracker.boss_dead       = true
            tracker.loot_start_time = get_time_since_inject()
            stats.record_kill(tracker.enter_time)
            on_boss_dead()
            task.status = 'boss gone — waiting for loot'
            console.print('[GemFarmer] Boss actor gone — movement skills restored')
        else
            task.status = string.format('returning to boss area (%.1fm)', tracker.boss_last_pos and player_pos:dist_to(tracker.boss_last_pos) or 0)
            if tracker.boss_last_pos then
                BatmobilePlugin.set_target(plugin_label, tracker.boss_last_pos, false)
                BatmobilePlugin.resume(plugin_label)
                BatmobilePlugin.update(plugin_label)
                BatmobilePlugin.move(plugin_label)
            end
        end
    end
end

return task

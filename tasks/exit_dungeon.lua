local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local world    = require 'core.world'

local RETRY_INTERVAL  = 10.0   -- seconds before firing leave_dungeon() again
local COMBAT_RANGE    = 10.0   -- metres — allow casting if enemy is within this range
local COMBAT_RANGE_SQ = COMBAT_RANGE * COMBAT_RANGE

local UR_ENABLED_HASH = get_hash('magoogles_universal_rotation_enabled')
local function set_ur_enabled(state)
    local el = checkbox:new(state, UR_ENABLED_HASH)
    el:set(state)
end

local function enemy_within_combat_range()
    local player = get_local_player()
    if not player then return false end
    local ppos = player:get_position()
    for _, actor in ipairs(actors_manager.get_enemy_actors()) do
        local ok, apos = pcall(function() return actor:get_position() end)
        if ok and apos then
            local dx = ppos:x() - apos:x()
            local dy = ppos:y() - apos:y()
            if (dx*dx + dy*dy) <= COMBAT_RANGE_SQ then return true end
        end
    end
    return false
end

local task = {
    name       = 'exit_dungeon',
    status     = 'idle',
    leave_time = -1,
    retries    = 0,
    suppressing_ur = false,
}

task.shouldExecute = function()
    if not world.is_inside() then return false end
    if not tracker.boss_dead then return false end
    if tracker.loot_start_time < 0 then return false end
    local elapsed = get_time_since_inject() - tracker.loot_start_time
    return elapsed >= settings.loot_wait
end

task.Execute = function()
    local now     = get_time_since_inject()
    local elapsed = task.leave_time >= 0 and (now - task.leave_time) or RETRY_INTERVAL

    -- Suppress UR while exiting unless an enemy is close enough to fight
    local enemy_close = enemy_within_combat_range()
    if enemy_close then
        if task.suppressing_ur then
            set_ur_enabled(true)
            _G.EXTERNAL_ROTATION_TARGET = nil
            task.suppressing_ur = false
        end
    else
        if not task.suppressing_ur then
            set_ur_enabled(false)
            task.suppressing_ur = true
        end
        _G.EXTERNAL_ROTATION_TARGET = nil
    end

    -- Fire leave_dungeon() on first call or every RETRY_INTERVAL seconds
    if elapsed >= RETRY_INTERVAL then
        task.retries    = task.retries + 1
        task.leave_time = now
        leave_dungeon()
        task.status = string.format('leaving dungeon (attempt %d)', task.retries)
        console.print(string.format('[GemFarmer] leave_dungeon() attempt %d', task.retries))
        return
    end

    task.status = string.format('waiting for zone transition (%.1fs / %.1fs)', elapsed, RETRY_INTERVAL)
end

local function restore_ur()
    if task.suppressing_ur then
        set_ur_enabled(true)
        _G.EXTERNAL_ROTATION_TARGET = nil
        task.suppressing_ur = false
    end
end

-- Reset state each run
local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    restore_ur()
    task.leave_time = -1
    task.retries    = 0
end

return task

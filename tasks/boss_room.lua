local tracker  = require 'core.tracker'
local settings = require 'core.settings'
local world    = require 'core.world'
local stats    = require 'core.stats'

local BOSS_ROOM_POS    = vec3:new(-1.6367, 0.8418, 1.8574)
local BOSS_ROOM_RANGE  = 25.0
local TREASURE_CHEST   = 'Warplans_NMD_3C_treasurebeast_chest_destructible'
local CHEST_SCAN_DIST  = 20.0
local INTERACT_RANGE   = 5.0
local CHEST_WAIT       = 3.0
local GOBLIN_RANGE     = 40.0
local BOSS_TIMEOUT     = 120.0
local GOBLIN_TIMEOUT   = 30.0
local CHEST_TIMEOUT    = 20.0

local task = {
    name              = 'boss_room',
    status            = 'idle',
    enter_time        = -1,
    goblin_target_id  = nil,
    goblin_chase_time = -1,
}

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    tracker.boss_dead         = false
    tracker.boss_chest_done   = false
    tracker.boss_died_time    = -1
    tracker.goblins_phase     = false
    task.enter_time           = -1
    task.goblin_target_id     = nil
    task.goblin_chase_time    = -1
end

local function in_boss_room(player_pos)
    return player_pos:dist_to(BOSS_ROOM_POS) <= BOSS_ROOM_RANGE
end

local function find_boss(player_pos)
    for _, actor in ipairs(actors_manager.get_enemy_actors()) do
        if actor:is_boss() then
            if actor:get_position():dist_to(player_pos) <= BOSS_ROOM_RANGE then
                return actor
            end
        end
    end
    return nil
end

local function find_treasure_chest(player_pos)
    for _, actor in ipairs(actors_manager.get_all_actors()) do
        local ok, name = pcall(function() return actor:get_skin_name() end)
        if ok and name == TREASURE_CHEST then
            local dist = actor:get_position():dist_to(player_pos)
            if dist <= CHEST_SCAN_DIST then
                local dead = false
                pcall(function() dead = actor:is_dead() end)
                if not dead then
                    return actor, dist
                end
            end
        end
    end
    return nil, nil
end

local function find_closest_enemy(player_pos, range)
    local closest, closest_dist = nil, math.huge
    local ok, actors = pcall(function() return actors_manager.get_enemy_actors() end)
    if not ok or type(actors) ~= 'table' then return nil end
    for _, actor in ipairs(actors) do
        local dead = true
        pcall(function() dead = actor:is_dead() end)
        if not dead then
            local dist = actor:get_position():dist_to(player_pos)
            if dist <= range and dist < closest_dist then
                closest      = actor
                closest_dist = dist
            end
        end
    end
    return closest
end

task.shouldExecute = function()
    if not world.is_in_dungeon() then return false end
    if not tracker.route_done then return false end
    if tracker.boss_chest_done then return false end
    return true
end

task.Execute = function()
    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()
    local now = get_time_since_inject()

    if task.enter_time < 0 then task.enter_time = now end

    if (now - task.enter_time) >= BOSS_TIMEOUT then
        console.print('[PathOfCoin] Boss room timeout — force skipping to clear phase')
        tracker.boss_chest_done = true
        return
    end

    -- Step 1: wait for boss to die
    if not tracker.boss_dead then
        local boss = find_boss(player_pos)
        if boss then
            if boss:is_dead() then
                tracker.boss_dead      = true
                tracker.boss_died_time = now
                task.status = 'boss dead — waiting for chest to spawn'
                console.print('[PathOfCoin] Boss dead — waiting for treasure chest')
            else
                task.status = 'waiting for boss to die'
            end
        else
            if in_boss_room(player_pos) then
                tracker.boss_dead      = true
                tracker.boss_died_time = now
                task.status = 'boss gone — waiting for chest to spawn'
                console.print('[PathOfCoin] Boss actor gone — assuming dead')
            else
                task.status = 'waiting in boss room'
            end
        end
        return
    end

    -- Step 2: wait a moment for chest to spawn
    if (now - tracker.boss_died_time) < CHEST_WAIT then
        task.status = string.format('waiting for chest spawn (%.1fs)', CHEST_WAIT - (now - tracker.boss_died_time))
        return
    end

    -- Step 3: find and attack the treasure chest
    if not tracker.goblins_phase then
        local chest, dist = find_treasure_chest(player_pos)
        if chest then
            if dist > INTERACT_RANGE then
                task.status = string.format('moving to treasure chest (%.1fm)', dist)
                pathfinder.request_move(chest:get_position())
            else
                task.status = 'attacking treasure chest'
                set_target(chest)
                tracker.goblins_phase = true
                console.print('[PathOfCoin] Attacking treasure chest — chasing goblins')
            end
        else
            if tracker.boss_died_time > 0 and (now - tracker.boss_died_time) > CHEST_TIMEOUT then
                console.print('[PathOfCoin] Chest not found after timeout — skipping to goblin phase')
                tracker.goblins_phase = true
            else
                task.status = 'scanning for treasure chest...'
            end
        end
        return
    end

    -- Step 4: chase and kill goblins
    local goblin = find_closest_enemy(player_pos, GOBLIN_RANGE)
    if goblin then
        local goblin_pos = goblin:get_position()
        local goblin_dist = goblin_pos:dist_to(player_pos)

        local gid = string.format('%.1f_%.1f', goblin_pos.x, goblin_pos.y)
        if task.goblin_target_id ~= gid then
            task.goblin_target_id  = gid
            task.goblin_chase_time = now
        elseif (now - task.goblin_chase_time) >= GOBLIN_TIMEOUT then
            console.print('[PathOfCoin] Goblin chase timeout — assuming unreachable, marking done')
            tracker.boss_chest_done = true
            return
        end

        task.status = string.format('chasing goblin (%.1fm)', goblin_dist)
        set_target(goblin)
        pathfinder.request_move(goblin_pos)
    else
        tracker.boss_chest_done = true
        stats.record_goblins()
        console.print('[PathOfCoin] Goblins dead — dungeon clear phase starting')
    end
end

return task

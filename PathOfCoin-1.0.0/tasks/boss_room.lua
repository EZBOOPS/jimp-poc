local tracker  = require 'core.tracker'
local settings = require 'core.settings'
local world    = require 'core.world'
local stats    = require 'core.stats'

local TREASURE_CHEST     = 'Warplans_NMD_3C_treasurebeast_chest_destructible'
local CHEST_SCAN_DIST    = 40.0
local INTERACT_RANGE     = 5.0
local GOBLIN_RANGE       = 40.0

-- Per-phase timeouts
local BOSS_WAIT_TIMEOUT  = 180.0  -- max wait for boss to appear and die
local CHEST_SPAWN_WAIT   = 4.0    -- wait after boss dies for chest to spawn
local CHEST_TIMEOUT      = 30.0   -- max time to find and kill chest after spawn wait
local CHEST_GONE_CONFIRM = 1.5    -- chest must be absent this long to confirm dead
local GOBLIN_SPAWN_WAIT  = 2.0    -- wait after chest dies for goblins to spawn
local GOBLIN_TIMEOUT     = 60.0   -- max time to kill all goblins

local PHASE = {
    WAIT_BOSS    = 1,
    WAIT_CHEST   = 2,
    KILL_CHEST   = 3,
    WAIT_GOBLINS = 4,
    KILL_GOBLINS = 5,
    DONE         = 6,
}

local task = {
    name              = 'boss_room',
    status            = 'idle',
    phase             = PHASE.WAIT_BOSS,
    phase_time        = -1,
    boss_seen         = false,   -- have we actually seen a live boss actor?
    chest_first_gone  = -1,
    chest_died_time   = -1,
    goblin_target_id  = nil,
    goblin_chase_time = -1,
}

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    tracker.boss_dead         = false
    tracker.boss_chest_done   = false
    tracker.boss_chest_time   = -1
    tracker.boss_died_time    = -1
    tracker.goblins_phase     = false
    task.phase                = PHASE.WAIT_BOSS
    task.phase_time           = -1
    task.boss_seen            = false
    task.chest_first_gone     = -1
    task.chest_died_time      = -1
    task.goblin_target_id     = nil
    task.goblin_chase_time    = -1
end

local function set_phase(p)
    task.phase      = p
    task.phase_time = get_time_since_inject()
    console.print(string.format('[PathOfCoin:boss] phase -> %d', p))
end

local function phase_elapsed()
    if task.phase_time < 0 then return 0 end
    return get_time_since_inject() - task.phase_time
end

local function find_boss(player_pos)
    local ok, actors = pcall(function() return actors_manager.get_enemy_actors() end)
    if not ok or type(actors) ~= 'table' then return nil, nil end
    for _, actor in ipairs(actors) do
        local is_boss = false
        pcall(function() is_boss = actor:is_boss() end)
        if is_boss then
            local dead = false
            pcall(function() dead = actor:is_dead() end)
            return actor, dead
        end
    end
    return nil, nil
end

local function find_treasure_chest(player_pos)
    local ok, actors = pcall(function() return actors_manager.get_all_actors() end)
    if not ok or type(actors) ~= 'table' then return nil, nil end
    for _, actor in ipairs(actors) do
        local ok2, name = pcall(function() return actor:get_skin_name() end)
        if ok2 and name == TREASURE_CHEST then
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

local function find_closest_goblin(player_pos)
    local closest, closest_dist = nil, math.huge
    local ok, actors = pcall(function() return actors_manager.get_enemy_actors() end)
    if not ok or type(actors) ~= 'table' then return nil end
    for _, actor in ipairs(actors) do
        local dead = true
        pcall(function() dead = actor:is_dead() end)
        if not dead then
            -- Only target enemies that appeared after goblins phase started (not the boss)
            local is_boss = false
            pcall(function() is_boss = actor:is_boss() end)
            if not is_boss then
                local dist = actor:get_position():dist_to(player_pos)
                if dist <= GOBLIN_RANGE and dist < closest_dist then
                    closest      = actor
                    closest_dist = dist
                end
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

    if task.phase_time < 0 then set_phase(PHASE.WAIT_BOSS) end

    -- PHASE 1: wait for boss to appear and die
    if task.phase == PHASE.WAIT_BOSS then
        local boss, boss_dead = find_boss(player_pos)
        if boss and not boss_dead then
            task.boss_seen = true
            task.status = 'waiting for boss to die'
        elseif boss and boss_dead then
            -- Boss found dead
            tracker.boss_dead      = true
            tracker.boss_died_time = now
            console.print('[PathOfCoin:boss] Boss dead — waiting for chest to spawn')
            set_phase(PHASE.WAIT_CHEST)
        elseif task.boss_seen then
            -- Was alive, now gone from actor list — dead and despawned
            tracker.boss_dead      = true
            tracker.boss_died_time = now
            console.print('[PathOfCoin:boss] Boss despawned after being seen — assuming dead')
            set_phase(PHASE.WAIT_CHEST)
        else
            -- Haven't seen boss yet
            if phase_elapsed() >= BOSS_WAIT_TIMEOUT then
                console.print('[PathOfCoin:boss] Boss wait timeout — skipping to chest phase')
                tracker.boss_dead      = true
                tracker.boss_died_time = now
                set_phase(PHASE.WAIT_CHEST)
            else
                task.status = string.format('waiting for boss to appear (%.0fs)', phase_elapsed())
            end
        end
        return
    end

    -- PHASE 2: wait for chest to spawn after boss dies
    if task.phase == PHASE.WAIT_CHEST then
        if phase_elapsed() >= CHEST_SPAWN_WAIT then
            console.print('[PathOfCoin:boss] Chest spawn wait done — scanning for chest')
            task.chest_first_gone = -1
            task.chest_died_time  = -1
            set_phase(PHASE.KILL_CHEST)
        else
            task.status = string.format('waiting for chest to spawn (%.1fs)', CHEST_SPAWN_WAIT - phase_elapsed())
        end
        return
    end

    -- PHASE 3: find and kill the treasure chest
    if task.phase == PHASE.KILL_CHEST then
        local chest, dist = find_treasure_chest(player_pos)
        if chest then
            task.chest_first_gone = -1  -- reset gone-timer, chest is visible
            if dist > INTERACT_RANGE then
                task.status = string.format('moving to treasure chest (%.1fm)', dist)
                pathfinder.request_move(chest:get_position())
            else
                task.status = 'attacking treasure chest'
                set_target(chest)
            end
        else
            -- Chest not visible
            if phase_elapsed() >= CHEST_TIMEOUT then
                console.print('[PathOfCoin:boss] Chest timeout — skipping to goblin phase')
                task.chest_died_time = now
                set_phase(PHASE.WAIT_GOBLINS)
                return
            end

            if task.chest_first_gone < 0 then
                task.chest_first_gone = now
                task.status = 'chest not visible — confirming...'
            else
                local gone_for = now - task.chest_first_gone
                if gone_for >= CHEST_GONE_CONFIRM then
                    console.print(string.format('[PathOfCoin:boss] Chest confirmed dead (absent %.1fs)', gone_for))
                    task.chest_died_time = now
                    set_phase(PHASE.WAIT_GOBLINS)
                else
                    task.status = string.format('confirming chest dead (%.1fs/%.1fs)', gone_for, CHEST_GONE_CONFIRM)
                end
            end
        end
        return
    end

    -- PHASE 4: wait for goblins to spawn after chest dies
    if task.phase == PHASE.WAIT_GOBLINS then
        if phase_elapsed() >= GOBLIN_SPAWN_WAIT then
            console.print('[PathOfCoin:boss] Goblin spawn wait done — chasing goblins')
            tracker.goblins_phase = true
            set_phase(PHASE.KILL_GOBLINS)
        else
            task.status = string.format('waiting for goblins to spawn (%.1fs)', GOBLIN_SPAWN_WAIT - phase_elapsed())
        end
        return
    end

    -- PHASE 5: chase and kill goblins
    if task.phase == PHASE.KILL_GOBLINS then
        if phase_elapsed() >= GOBLIN_TIMEOUT then
            console.print('[PathOfCoin:boss] Goblin timeout — marking done')
            tracker.boss_chest_done = true
            return
        end

        local goblin = find_closest_goblin(player_pos)
        if goblin then
            local goblin_pos  = goblin:get_position()
            local goblin_dist = goblin_pos:dist_to(player_pos)
            local gid         = string.format('%.1f_%.1f', goblin_pos.x, goblin_pos.y)

            if task.goblin_target_id ~= gid then
                task.goblin_target_id  = gid
                task.goblin_chase_time = now
            elseif (now - task.goblin_chase_time) >= 30.0 then
                console.print('[PathOfCoin:boss] Single goblin stuck — skipping it')
                task.goblin_target_id  = nil
                task.goblin_chase_time = -1
                return
            end

            set_target(goblin)
            if goblin_dist <= 4.0 then
                task.status = string.format('attacking goblin (%.1fm)', goblin_dist)
                interact_object(goblin)
            else
                task.status = string.format('chasing goblin (%.1fm)', goblin_dist)
                pathfinder.request_move(goblin_pos)
            end
        else
            console.print('[PathOfCoin:boss] All goblins dead — dungeon clear')
            stats.record_goblins()
            tracker.boss_chest_done = true
        end
        return
    end
end

return task

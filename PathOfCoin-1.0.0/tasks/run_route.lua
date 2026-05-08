local tracker  = require 'core.tracker'
local settings = require 'core.settings'
local world    = require 'core.world'

local CHEST_NAME     = 'Firstborn_Prop_Chest_Rare_Lava_Dyn'
local WAYPOINT_REACH = 5.0
local BOSS_POS       = vec3:new(-1.3691, -0.6045, 1.8574)
local BOSS_ARRIVE    = 30.0

local WAYPOINTS = {
    vec3:new(106.3027, 43.1172, 0.0000),
    vec3:new(103.3240, 42.3775, 0.0000),
    vec3:new(100.3558, 41.5354, 0.0007),
    vec3:new(97.3942,  40.8841, 0.0574),
    vec3:new(94.4631,  39.9242, 0.0000),
    vec3:new(91.7324,  38.5838, -0.1210),
    vec3:new(89.0441,  37.2335, -0.2498),
    vec3:new(86.1166,  36.5414, 0.2771),
    vec3:new(83.0451,  36.7881, 0.3015),
    vec3:new(80.1113,  37.4483, 0.1922),
    vec3:new(77.3142,  38.5461, -0.2907),
    vec3:new(78.8827,  41.0338, 0.4197),
    vec3:new(78.5352,  43.9944, 0.8506),
    vec3:new(78.6397,  47.0317, 0.6589),
    vec3:new(81.3424,  48.3882, 0.0989),
    vec3:new(83.5674,  50.3995, -0.4741),
    vec3:new(83.7740,  53.4121, 0.0506),
    vec3:new(82.1668,  55.9589, -0.0409),
    vec3:new(79.5014,  57.4715, 0.0308),
    vec3:new(76.5085,  57.8444, -0.0763),
    vec3:new(73.5352,  57.3232, -0.0820),
    vec3:new(70.7249,  56.2485, -0.3418),
    vec3:new(68.2168,  54.6694, -0.0894),
    vec3:new(65.9746,  52.7427, 0.3604),
    vec3:new(63.5977,  51.1245, 0.6128),
    vec3:new(61.0063,  50.1604, 0.2178),
    vec3:new(58.2148,  49.9268, -0.0574),
    vec3:new(55.3994,  49.5693, -0.0779),
    vec3:new(52.5576,  49.4380, 0.0000),
    vec3:new(49.7578,  49.7017, 0.2722),
    vec3:new(47.1099,  50.6245, 0.6128),
    vec3:new(44.6997,  52.0601, 0.3052),
    vec3:new(42.5518,  53.8784, -0.1328),
    vec3:new(40.3447,  55.5874, -0.3052),
    vec3:new(37.8438,  56.8071, -0.3418),
    vec3:new(35.1270,  57.3486, -0.0820),
    vec3:new(32.3223,  57.2319, 0.3052),
    vec3:new(29.5938,  56.5894, 0.5859),
    vec3:new(27.1470,  55.2837, 0.3052),
    vec3:new(25.0605,  53.4277, -0.1943),
    vec3:new(23.2080,  51.3228, -0.5127),
    vec3:new(21.0083,  49.6323, -0.3052),
    vec3:new(18.4556,  48.6245, -0.0574),
    vec3:new(15.6348,  48.3735, 0.0000),
    vec3:new(12.8081,  48.5811, 0.3052),
    vec3:new(10.1416,  49.3608, 0.6128),
    vec3:new(7.7666,   50.7075, 0.3052),
    vec3:new(5.6934,   52.5234, -0.1943),
    vec3:new(3.8711,   54.6323, -0.5127),
    vec3:new(2.2041,   56.9619, -0.3052),
    vec3:new(0.6543,   59.3608, -0.0574),
    vec3:new(-0.8154,  61.7900, 0.0000),
    vec3:new(-2.1250,  64.2837, 0.0000),
    vec3:new(-3.1543,  66.8882, 0.0000),
    vec3:new(-3.8457,  69.5693, 0.0000),
    vec3:new(-4.1367,  72.2900, 0.0000),
    vec3:new(-3.9941,  75.0225, 0.0000),
    vec3:new(-3.4043,  77.7075, 0.0000),
    vec3:new(-2.3750,  80.2900, 0.0000),
    vec3:new(-0.9043,  82.6870, 0.0000),
    vec3:new(0.9238,   84.8442, 0.0000),
    vec3:new(3.0693,   86.6870, 0.0000),
    vec3:new(5.4834,   88.1245, 0.0000),
    vec3:new(8.0840,   89.1245, 0.0000),
    vec3:new(10.8096,  89.6870, 0.0000),
    vec3:new(13.5781,  89.7837, 0.0000),
    vec3:new(16.3076,  89.4121, 0.0000),
    vec3:new(18.9385,  88.5693, 0.0000),
    vec3:new(21.3330,  87.2837, 0.0000),
    vec3:new(23.4609,  85.5693, 0.0000),
    vec3:new(25.2539,  83.4932, 0.0000),
    vec3:new(26.6504,  81.1245, 0.0000),
    vec3:new(27.5996,  78.5459, 0.0000),
    vec3:new(28.0664,  75.8315, 0.0000),
    vec3:new(28.0430,  73.0908, 0.0000),
    vec3:new(27.5254,  70.3872, 0.0000),
    vec3:new(26.5293,  67.8071, 0.0000),
    vec3:new(25.0938,  65.4199, 0.0000),
    vec3:new(23.2715,  63.2959, 0.0000),
    vec3:new(21.1270,  61.5010, 0.0000),
    vec3:new(18.7070,  60.0908, 0.0000),
    vec3:new(16.0820,  59.1089, 0.0000),
    vec3:new(13.3398,  58.5771, 0.0000),
    vec3:new(10.5625,  58.5107, 0.0000),
    vec3:new(7.8086,   58.9121, 0.0000),
    vec3:new(5.2285,   59.7686, 0.0000),
    vec3:new(2.8594,   61.0615, 0.0000),
    vec3:new(0.7441,   62.7471, 0.0000),
    vec3:new(-1.0469,  64.7686, 0.0000),
    vec3:new(-2.4531,  67.0693, 0.0000),
    vec3:new(-3.4277,  69.5850, 0.0000),
}

local TELEPORT_SPELL_ID = 288106
local TELEPORT_MIN_DIST = 8.0

local STUCK_THRESHOLD    = 8.0
local STUCK_DIST         = 1.0
local WRONG_INSTANCE_WP  = 20  -- if past this waypoint with 0 chests, assume wrong instance

local task = {
    name            = 'run_route',
    status          = 'idle',
    wp_index        = 1,
    chests_on_route = 0,
    stuck_pos       = nil,
    stuck_time      = -1,
}

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    task.wp_index        = 1
    task.chests_on_route = 0
    task.stuck_pos       = nil
    task.stuck_time      = -1
end

local function try_teleport(pos, player_pos)
    if not settings.use_teleport then return false end
    local dist = player_pos:dist_to(pos)
    if dist < TELEPORT_MIN_DIST then return false end
    local ok, can = pcall(function() return utility.can_cast_spell(TELEPORT_SPELL_ID) end)
    if not ok or not can then return false end
    pcall(function() cast_spell.position(TELEPORT_SPELL_ID, pos, 0) end)
    return true
end

local function find_chest(player_pos, range)
    for _, actor in ipairs(actors_manager.get_all_actors()) do
        local ok, name = pcall(function() return actor:get_skin_name() end)
        if ok and name and name:find(CHEST_NAME) then
            local dist = actor:get_position():dist_to(player_pos)
            if dist <= range then
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

task.shouldExecute = function()
    if not world.is_in_dungeon() then return false end
    if tracker.route_done then return false end
    if settings.use_social_connector and not tracker.left_party then return false end
    return true
end

task.Execute = function()
    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()
    local now = get_time_since_inject()

    -- Wrong instance check: past checkpoint with no chests found — leave party
    if settings.open_chests and task.wp_index > WRONG_INSTANCE_WP and task.chests_on_route == 0 then
        console.print('[PathOfCoin] Past waypoint ' .. WRONG_INSTANCE_WP .. ' with no chests — wrong instance, firing social connector')
        tracker.route_done = true  -- stop routing so social can fire
        return
    end

    -- Batmobile rush mode
    if settings.batmobile_rush then
        local dist_to_boss = player_pos:dist_to(BOSS_POS)
        if dist_to_boss <= BOSS_ARRIVE then
            tracker.route_done = true
            task.status = 'arrived at boss room (Batmobile)'
            console.print('[PathOfCoin] Batmobile: arrived at boss room')
            return
        end
        local ok, navigating = pcall(function() return BatmobilePlugin.is_long_path_navigating() end)
        if not ok or not navigating then
            pcall(function() BatmobilePlugin.navigate_long_path('PathOfCoin', BOSS_POS) end)
        end
        task.status = string.format('Batmobile rushing to boss (%.1fm)', dist_to_boss)
        return
    end

    -- Open chests on the way if enabled
    if settings.open_chests then
        local chest, cdist = find_chest(player_pos, settings.chest_range or 15.0)
        if chest then
            if cdist > 3.0 then
                task.status = string.format('moving to chest (%.1fm)', cdist)
                if not try_teleport(chest:get_position(), player_pos) then
                    pathfinder.request_move(chest:get_position())
                end
                return
            else
                interact_object(chest)
                tracker.chests_opened = tracker.chests_opened + 1
                task.chests_on_route  = task.chests_on_route + 1
                task.status = string.format('opened chest #%d', task.chests_on_route)
                if settings.loot_wait and settings.loot_wait > 0 then
                    -- brief pause handled by tick rate
                end
                return
            end
        end
    end

    -- Follow waypoints
    local wp = WAYPOINTS[task.wp_index]
    if not wp then
        tracker.route_done = true
        task.status = 'route complete — heading to boss'
        console.print('[PathOfCoin] Waypoint route done')
        return
    end

    local dist = player_pos:dist_to(wp)

    -- Stuck detection
    local pos_key = string.format('%.0f_%.0f', player_pos.x, player_pos.y)
    if task.stuck_pos ~= pos_key then
        task.stuck_pos  = pos_key
        task.stuck_time = now
    elseif (now - task.stuck_time) >= STUCK_THRESHOLD then
        console.print(string.format('[PathOfCoin] Stuck at waypoint %d — skipping', task.wp_index))
        task.wp_index   = task.wp_index + 1
        task.stuck_pos  = nil
        task.stuck_time = -1
        return
    end

    if dist <= WAYPOINT_REACH then
        task.wp_index  = task.wp_index + 1
        task.stuck_pos = nil
        task.stuck_time = -1
        return
    end

    task.status = string.format('waypoint %d/%d (%.1fm)', task.wp_index, #WAYPOINTS, dist)
    if not try_teleport(wp, player_pos) then
        pathfinder.request_move(wp)
    end
end

return task

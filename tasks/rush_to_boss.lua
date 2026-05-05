local settings      = require 'core.settings'
local tracker       = require 'core.tracker'
local world         = require 'core.world'
local stuck_timeout = require 'tasks.stuck_timeout'

local plugin_label = 'gem_farmer'

local ENTRY_DELAY         = 1.0    -- seconds after entering before starting navigation
local WELL_INTERACT_RANGE = 6.0    -- metres — interact with healing well
local BOSS_POS            = vec3:new(-5.1768, -3.9268, 2.0000)
local BOSS_PATHFIND_DIST  = 20.0   -- switch to pathfinder within this range (narrow path)

local NAV_SAMPLE_INTERVAL = 6.0    -- seconds between position snapshots
local NAV_STUCK_DIST      = 10.0   -- units — must have moved this far each interval or free-roam

-- Slide re-steer: if the player hasn't moved this far within SLIDE_STUCK_TIME
-- seconds during an active wall-slide, the slide target is blocked by a new wall
-- corner. Fan out angles from the current slide direction to find a walkable exit.
local SLIDE_STUCK_TIME  = 1.5   -- seconds of no movement before re-steering
local SLIDE_STUCK_DIST  = 1.5   -- units — minimum movement to count as "not stuck"
local SLIDE_FAN_STEP    = 15    -- degrees per fan step
local SLIDE_FAN_MAX     = 180   -- max degrees to fan either side before giving up
local SLIDE_PROBE_DIST  = 8.0   -- units — how far ahead to probe walkability

-- Wall zone A: X=[0,82] Y=[95,120] — stuck around Y~97-107, move right to X=95
local WALLA_X_MIN      =  0.0
local WALLA_X_MAX      = 82.0
local WALLA_Y_MIN      = 95.0
local WALLA_Y_MAX      = 120.0
local WALLA_BYPASS_POS = vec3:new(95.0, 97.0, 0.0)

local function in_walla_zone(pos)
    local x, y = pos:x(), pos:y()
    return x >= WALLA_X_MIN and x <= WALLA_X_MAX
       and y >= WALLA_Y_MIN and y <= WALLA_Y_MAX
end

-- Wall zone B: X=[0,72] Y=[120,145] — stuck around Y~137, move right to X=73
local WALLB_X_MIN      =  0.0
local WALLB_X_MAX      = 72.0
local WALLB_Y_MIN      = 120.0
local WALLB_Y_MAX      = 145.0
local WALLB_BYPASS_POS = vec3:new(73.0527, 137.0479, -0.0723)

local function in_wallb_zone(pos)
    local x, y = pos:x(), pos:y()
    return x >= WALLB_X_MIN and x <= WALLB_X_MAX
       and y >= WALLB_Y_MIN and y <= WALLB_Y_MAX
end

-- Wall zone C: X=[80,100] Y=[65,88] — bot goes south into wall at Y~75, route west
local WALLC_X_MIN      = 80.0
local WALLC_X_MAX      = 100.0
local WALLC_Y_MIN      = 65.0
local WALLC_Y_MAX      = 88.0
local WALLC_BYPASS_POS = vec3:new(70.0, 80.0, 0.0)

local function in_wallc_zone(pos)
    local x, y = pos:x(), pos:y()
    return x >= WALLC_X_MIN and x <= WALLC_X_MAX
       and y >= WALLC_Y_MIN and y <= WALLC_Y_MAX
end

-- Wall zone D: X=[155,172] Y=[65,88] — stuck at Y~79, move to (173, 69)
local WALLD_X_MIN      = 155.0
local WALLD_X_MAX      = 172.0
local WALLD_Y_MIN      = 65.0
local WALLD_Y_MAX      = 88.0
local WALLD_BYPASS_POS = vec3:new(173.0840, 69.3125, 0.0410)

local function in_walld_zone(pos)
    local x, y = pos:x(), pos:y()
    return x >= WALLD_X_MIN and x <= WALLD_X_MAX
       and y >= WALLD_Y_MIN and y <= WALLD_Y_MAX
end

-- Second wall zone: X=[90,115] Y=[-5,25] — bot must move right to bypass
local WALL2_X_MIN      = 90.0
local WALL2_X_MAX      = 115.0
local WALL2_Y_MIN      = -5.0
local WALL2_Y_MAX      = 25.0
local WALL2_BYPASS_POS = vec3:new(105.4229, 48.9453, 9.4629)

local function in_wall2_zone(pos)
    local x, y = pos:x(), pos:y()
    return x >= WALL2_X_MIN and x <= WALL2_X_MAX
       and y >= WALL2_Y_MIN and y <= WALL2_Y_MAX
end

local task = {
    name             = 'rush_to_boss',
    status           = 'idle',
    well_done        = false,
    nav_sample_pos   = nil,
    nav_sample_time  = -1,
    -- Slide re-steer state
    slide_last_pos       = nil,
    slide_last_move_time = -1,
}

local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    task.well_done           = false
    task.nav_sample_pos      = nil
    task.nav_sample_time     = -1
    task.slide_last_pos      = nil
    task.slide_last_move_time = -1
end

local function is_butcher(actor)
    local name = actor:get_skin_name()
    return name and name:lower():find('butcher') ~= nil
end

local function find_boss(player_pos)
    for _, actor in ipairs(actors_manager.get_enemy_actors()) do
        if actor:is_boss() and not actor:is_dead() and not is_butcher(actor) then
            if actor:get_position():dist_to(player_pos) < settings.boss_range then
                return actor
            end
        end
    end
    return nil
end

-- Returns true if the well was found (caller should skip Batmobile exploration)
local function try_interact_well(player_pos)
    if task.well_done then return false end
    for _, actor in ipairs(actors_manager.get_all_actors()) do
        local name = actor:get_skin_name() or ''
        if name == 'Healing_Well_Basic' then
            local dist = actor:get_position():dist_to(player_pos)
            if dist <= WELL_INTERACT_RANGE then
                console.print(string.format('[GemFarmer] Interacting with Healing_Well_Basic (%.1fm)', dist))
                interact_object(actor)
                task.well_done = true
                return false  -- done, resume exploration
            else
                -- Pause Batmobile and beeline directly to the well
                BatmobilePlugin.pause(plugin_label)
                pathfinder.request_move(actor:get_position())
                task.status = string.format('beelining to healing well (%.1fm)', dist)
                return true
            end
        end
    end
    return false
end

task.shouldExecute = function()
    return world.is_inside() and not tracker.boss_found and not tracker.boss_dead
end

task.Execute = function()
    if BatmobilePlugin == nil then
        task.status = 'ERROR: BatmobilePlugin not loaded'
        return
    end

    local now = get_time_since_inject()

    -- Wall-slide: active when stuck_timeout detected oscillation or no-progress.
    -- Each tick we re-project a perpendicular target from the current position so
    -- the slide arcs around corners. A separate mini stuck-check runs inside the
    -- slide: if the player stops moving (new wall corner blocking the slide target),
    -- fan out angles from the current slide direction to find the new wall face and
    -- re-steer. Uses force_move to override request_move's "already moving" guard.
    if stuck_timeout.slide_until > 0 and now < stuck_timeout.slide_until then
        local player_s = get_local_player()
        if player_s then
            local spos      = player_s:get_position()
            local remaining = stuck_timeout.slide_until - now

            -- Initialise slide movement tracker on first tick of this slide
            if task.slide_last_pos == nil then
                task.slide_last_pos       = spos
                task.slide_last_move_time = now
            end

            -- Check if we've moved enough since last sample
            if spos:dist_to(task.slide_last_pos) >= SLIDE_STUCK_DIST then
                task.slide_last_pos       = spos
                task.slide_last_move_time = now
            end

            local slide_blocked = (now - task.slide_last_move_time) >= SLIDE_STUCK_TIME

            if slide_blocked then
                -- Fan angles from current slide direction to find a walkable exit.
                -- Current slide direction as a unit vector:
                local slide_target_ref = stuck_timeout.get_slide_target(spos)
                local cur_dx = slide_target_ref:x() - spos:x()
                local cur_dy = slide_target_ref:y() - spos:y()
                local cur_len = math.sqrt(cur_dx * cur_dx + cur_dy * cur_dy)
                if cur_len > 0.001 then cur_dx = cur_dx / cur_len; cur_dy = cur_dy / cur_len end

                local found_dx, found_dy = nil, nil
                for deg = SLIDE_FAN_STEP, SLIDE_FAN_MAX, SLIDE_FAN_STEP do
                    for _, sign in ipairs({ 1, -1 }) do
                        local rad = math.rad(deg * sign)
                        local cos_r, sin_r = math.cos(rad), math.sin(rad)
                        local tx = cur_dx * cos_r - cur_dy * sin_r
                        local ty = cur_dx * sin_r + cur_dy * cos_r
                        local probe = vec3:new(spos:x() + tx * SLIDE_PROBE_DIST,
                                               spos:y() + ty * SLIDE_PROBE_DIST,
                                               spos:z())
                        probe = utility.set_height_of_valid_position(probe)
                        if utility.is_point_walkeable(probe) then
                            found_dx, found_dy = tx, ty
                            break
                        end
                    end
                    if found_dx then break end
                end

                if found_dx then
                    -- Determine which perpendicular side this new direction is closest
                    -- to so slide_dir stays meaningful for get_slide_target next tick.
                    -- Cross product of boss-forward with found dir: positive = left.
                    local bx = BOSS_POS:x() - spos:x()
                    local by = BOSS_POS:y() - spos:y()
                    local blen = math.sqrt(bx * bx + by * by)
                    if blen > 0.001 then bx = bx / blen; by = by / blen end
                    local cross = bx * found_dy - by * found_dx
                    stuck_timeout.slide_dir = cross >= 0 and 1 or -1

                    local new_target = vec3:new(spos:x() + found_dx * SLIDE_DIST,
                                                spos:y() + found_dy * SLIDE_DIST,
                                                spos:z())
                    new_target = utility.set_height_of_valid_position(new_target)
                    task.status = string.format('wall-slide re-steer (%.1fs, dir=%+d)', remaining, stuck_timeout.slide_dir)
                    console.print(string.format('[GemFarmer] Wall-slide re-steering (blocked %.1fs) — new dir=%+d', now - task.slide_last_move_time, stuck_timeout.slide_dir))
                    task.slide_last_pos       = spos
                    task.slide_last_move_time = now
                    BatmobilePlugin.pause(plugin_label)
                    pathfinder.force_move(new_target)
                else
                    -- No walkable angle found — end slide early, let boss-progress
                    -- guard handle abandonment if it persists
                    console.print('[GemFarmer] Wall-slide: no walkable angle found — ending slide early')
                    stuck_timeout.slide_until = -1
                    task.slide_last_pos       = nil
                    task.slide_last_move_time = -1
                end
            else
                local slide_target = stuck_timeout.get_slide_target(spos)
                task.status = string.format('wall-sliding (%.1fs, dir=%+d)', remaining, stuck_timeout.slide_dir)
                BatmobilePlugin.pause(plugin_label)
                pathfinder.request_move(slide_target)
            end
        end
        -- Reset nav sample so stuck-check starts fresh after slide ends
        task.nav_sample_pos  = nil
        task.nav_sample_time = -1
        return
    end
    if stuck_timeout.slide_until > 0 and now >= stuck_timeout.slide_until then
        -- Slide just finished
        stuck_timeout.slide_until    = -1
        task.slide_last_pos          = nil
        task.slide_last_move_time    = -1
        task.nav_sample_pos          = nil
        task.nav_sample_time         = -1
        console.print('[GemFarmer] Wall-slide done — resuming boss path')
    end

    if tracker.enter_time > 0 and (now - tracker.enter_time) < ENTRY_DELAY then
        task.status = 'waiting for dungeon load'
        return
    end

    local player = get_local_player()
    if not player then return end
    local player_pos = player:get_position()

    -- Nav stuck detection: snapshot position every NAV_SAMPLE_INTERVAL seconds.
    -- If less than NAV_STUCK_DIST units moved → trigger wall-slide via stuck_timeout.
    if task.nav_sample_pos == nil then
        task.nav_sample_pos  = player_pos
        task.nav_sample_time = now
    elseif (now - task.nav_sample_time) >= NAV_SAMPLE_INTERVAL then
        local units_moved = player_pos:dist_to(task.nav_sample_pos)
        if units_moved < NAV_STUCK_DIST then
            console.print(string.format('[GemFarmer] Nav stuck (%.1f units in %.0fs) — starting wall-slide', units_moved, NAV_SAMPLE_INTERVAL))
            stuck_timeout.slide_dir   = stuck_timeout.pick_slide_dir(player_pos)
            stuck_timeout.slide_until = now + settings.slide_duration
            task.slide_last_pos       = nil
            task.slide_last_move_time = -1
            task.nav_sample_pos       = nil
            task.nav_sample_time      = -1
            return
        end
        task.nav_sample_pos  = player_pos
        task.nav_sample_time = now
    end

    -- Boss check first
    local boss = find_boss(player_pos)
    if boss then
        tracker.boss_found    = true
        tracker.boss_last_pos = boss:get_position()
        BatmobilePlugin.pause(plugin_label)
        pathfinder.request_move(player_pos)  -- cancel any ongoing final-approach move
        console.print('[GemFarmer] Boss detected — handing off to fight task')
        return
    end

    -- Healing well — beeline if spotted, otherwise drive to boss coords
    if try_interact_well(player_pos) then return end

    if settings.wall_detours then
        if in_walla_zone(player_pos) then
            BatmobilePlugin.pause(plugin_label)
            task.status = string.format('detouring wall A (%.1fm)', player_pos:dist_to(WALLA_BYPASS_POS))
            pathfinder.request_move(WALLA_BYPASS_POS)
            return
        end
        if in_wallb_zone(player_pos) then
            BatmobilePlugin.pause(plugin_label)
            task.status = string.format('detouring wall B (%.1fm)', player_pos:dist_to(WALLB_BYPASS_POS))
            pathfinder.request_move(WALLB_BYPASS_POS)
            return
        end
        if in_wallc_zone(player_pos) then
            BatmobilePlugin.pause(plugin_label)
            task.status = string.format('detouring wall C (%.1fm)', player_pos:dist_to(WALLC_BYPASS_POS))
            pathfinder.request_move(WALLC_BYPASS_POS)
            return
        end
        if in_walld_zone(player_pos) then
            BatmobilePlugin.pause(plugin_label)
            task.status = string.format('detouring wall D (%.1fm)', player_pos:dist_to(WALLD_BYPASS_POS))
            pathfinder.request_move(WALLD_BYPASS_POS)
            return
        end
        if in_wall2_zone(player_pos) then
            BatmobilePlugin.pause(plugin_label)
            task.status = string.format('detouring wall2 (%.1fm)', player_pos:dist_to(WALL2_BYPASS_POS))
            pathfinder.request_move(WALL2_BYPASS_POS)
            return
        end
    end

    local boss_dist = player_pos:dist_to(BOSS_POS)
    if boss_dist <= BOSS_PATHFIND_DIST then
        BatmobilePlugin.pause(plugin_label)
        -- Arrived at boss area — force handoff to fight task
        if boss_dist <= 8.0 then
            tracker.boss_found    = true
            tracker.boss_last_pos = BOSS_POS
            pathfinder.request_move(player_pos)
            console.print('[GemFarmer] Arrived at boss area — forcing fight handoff')
            return
        end
        task.status = string.format('final approach to boss (%.1fm)', boss_dist)
        pathfinder.request_move(BOSS_POS)
    else
        -- Longer stretch — Batmobile drives
        task.status = string.format('heading to boss (%.1fm)', boss_dist)
        BatmobilePlugin.set_target(plugin_label, BOSS_POS, false)
        BatmobilePlugin.resume(plugin_label)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)
    end
end

return task

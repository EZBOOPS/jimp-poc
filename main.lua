local gui             = require 'gui'
local settings        = require 'core.settings'
local task_manager    = require 'core.task_manager'
local tracker         = require 'core.tracker'
local world           = require 'core.world'
local social          = require 'tasks.social_connector'
local stats           = require 'core.stats'

local plugin_version = gui.plugin_version
console.print('Lua Plugin - Path of Coin - v' .. plugin_version)

local function draw_crosshair(cx, cy, label, col)
    local arm = 12
    graphics.line(vec2:new(cx - arm, cy), vec2:new(cx + arm, cy), col, 2)
    graphics.line(vec2:new(cx, cy - arm), vec2:new(cx, cy + arm), col, 2)
    graphics.circle_2d(vec2:new(cx, cy), 5, col, 1)
    graphics.text_2d(label, vec2:new(cx + 14, cy - 8), 14, col)
end

local GOLD_MAX_RANGE   = 60.0
local gold_skip        = {}   -- set of position keys for gold pieces to skip
local idle_since       = -1
local IDLE_FIRE_DELAY  = 4.0
local hang_last_task   = nil
local hang_last_time   = -1
local HANG_TIMEOUT     = 20.0

on_update(function()
    settings.update()  -- always update so sliders are live even when disabled
    if not get_local_player() then return end
    if not settings.enabled then return end

    local now = get_time_since_inject()

    -- Pause everything while Alfred is actively running
    if settings.use_alfred then
        local alfred = _G.AlfredTheButlerPlugin
        if alfred and type(alfred.get_status) == 'function' then
            local ok, s = pcall(alfred.get_status)
            if ok and type(s) == 'table' then
                -- If Alfred needs to run (seals/inventory full) and isn't already triggered, fire it
                if s.enabled and (s.talisman_full or s.need_trigger) and not s.trigger_tasks then
                    if type(alfred.trigger_tasks) == 'function' then
                        alfred.trigger_tasks('PathOfCoin')
                        console.print('[PathOfCoin] Triggered Alfred — seals/inventory full')
                    end
                end
                -- Pause PathOfCoin while Alfred is doing its town run
                if s.trigger_tasks then
                    return
                end
            end
        end
    end

    if world.is_in_dungeon() then

        local gold_in_progress = tracker.boss_chest_done and not tracker.gold_pickup_done

        if settings.use_social_connector and social.step == 0 then
            local cur = task_manager.get_current_task()
            local cur_name = cur and cur.name or 'Idle'

            -- Watchdog 1: task manager truly idle for 4s (not while gold pickup is running)
            if cur_name == 'Idle' and not gold_in_progress then
                if idle_since < 0 then idle_since = now end
                if (now - idle_since) >= IDLE_FIRE_DELAY then
                    console.print('[PathOfCoin] Idle watchdog fired after ' .. IDLE_FIRE_DELAY .. 's — starting social')
                    idle_since = -1
                    social.start()
                end
            else
                idle_since = -1
            end

            -- Watchdog 2: task stuck on same name for 20s, but ONLY after boss/goblins are done
            -- boss_room and run_route are legitimate long-running tasks, don't interrupt them
            if cur_name ~= 'Idle' and tracker.boss_chest_done and tracker.gold_pickup_done then
                if cur_name ~= hang_last_task then
                    hang_last_task = cur_name
                    hang_last_time = now
                elseif (now - hang_last_time) >= HANG_TIMEOUT then
                    console.print('[PathOfCoin] Hang watchdog: task ' .. cur_name .. ' stuck for ' .. HANG_TIMEOUT .. 's — starting social')
                    hang_last_task = nil
                    hang_last_time = -1
                    social.start()
                end
            else
                hang_last_task = nil
                hang_last_time = -1
            end
        else
            idle_since     = -1
            hang_last_task = nil
            hang_last_time = -1
        end

        task_manager.execute_tasks()

        -- Track when boss_chest_done first became true so gold has time to land
        if tracker.boss_chest_done and tracker.boss_chest_time < 0 then
            tracker.boss_chest_time = now
        end

        -- Gold pickup overall timeout: if it takes more than 20s just move on
        if tracker.boss_chest_done and not tracker.gold_pickup_done
           and tracker.boss_chest_time > 0 and (now - tracker.boss_chest_time) >= 23.0 then
            console.print('[PathOfCoin] Gold pickup timeout — skipping to social')
            tracker.gold_pickup_done = true
            tracker.gold_stuck_pos   = nil
            tracker.gold_stuck_time  = -1
            gold_skip                = {}
        end

        -- Pick up gold on the floor before firing social connector (wait 3s for loot to settle)
        if tracker.boss_chest_done and not tracker.gold_pickup_done
           and (now - tracker.boss_chest_time) >= 3.0 then
            local player = get_local_player()
            if player then
                local player_pos = player:get_position()
                local closest_gold, closest_dist, closest_key = nil, math.huge, nil
                local ok, items = pcall(function() return actors_manager:get_all_items() end)
                if ok and type(items) == 'table' then
                    for _, item in ipairs(items) do
                        local is_gold = false
                        pcall(function() is_gold = loot_manager.is_gold(item) end)
                        if is_gold then
                            local ipos = item:get_position()
                            local key  = string.format('%.1f_%.1f', ipos.x, ipos.y)
                            if not gold_skip[key] then
                                local dist = ipos:dist_to(player_pos)
                                if dist <= GOLD_MAX_RANGE and dist < closest_dist then
                                    closest_gold = item
                                    closest_dist = dist
                                    closest_key  = key
                                end
                            end
                        end
                    end
                end

                if closest_gold then
                    if tracker.gold_stuck_pos ~= closest_key then
                        tracker.gold_stuck_pos  = closest_key
                        tracker.gold_stuck_time = now
                    elseif (now - tracker.gold_stuck_time) >= 3.0 then
                        console.print('[PathOfCoin] Gold stuck — blacklisting ' .. closest_key)
                        gold_skip[closest_key]  = true
                        tracker.gold_stuck_pos  = nil
                        tracker.gold_stuck_time = -1
                        closest_gold = nil
                    end

                    if closest_gold then
                        if closest_dist <= 2.0 then
                            interact_object(closest_gold)
                        else
                            pathfinder.request_move(closest_gold:get_position())
                        end
                    end
                else
                    tracker.gold_pickup_done = true
                    tracker.gold_stuck_pos   = nil
                    tracker.gold_stuck_time  = -1
                    gold_skip                = {}
                    console.print('[PathOfCoin] Gold pickup done')
                end
            end
        end

        -- Fire social connector only after boss chest and gold pickup are done
        if settings.use_social_connector then
            if social.step == 0 and tracker.boss_chest_done and tracker.gold_pickup_done then
                social.start()
            end
            if social.step ~= nil and social.step > 0 then social.Execute() end
        end
    else
        if settings.use_social_connector then
            -- If in Temerity and Alfred is not running, kick off the social connector
            if world.is_in_temerity() and social.step == 0 then
                local alfred = _G.AlfredTheButlerPlugin
                local alfred_busy = false
                if alfred and type(alfred.get_status) == 'function' then
                    local ok, s = pcall(alfred.get_status)
                    if ok and type(s) == 'table' then alfred_busy = s.trigger_tasks end
                end
                if not alfred_busy then
                    social.start()
                end
            end
            if social.step ~= nil and social.step > 0 then
                social.Execute()
            end
        end
    end
end)

on_render(function()
    settings.update()  -- keep settings fresh for render even if on_update returned early
    -- Click point crosshairs render even when disabled so you can calibrate
    if settings.show_click_points then
        draw_crosshair(settings.social_friend_x,    settings.social_friend_y,    '1. Friend',        color_green(220))
        draw_crosshair(settings.social_join_x,      settings.social_join_y,      '2. Join Party',    color_cyan(220))
        draw_crosshair(settings.social_transfer_x,  settings.social_transfer_y,  '3. Transfer Now',  color_yellow(220))
        draw_crosshair(settings.social_leave_x,     settings.social_leave_y,     '4. Leave Party',   color_orange(220))
        draw_crosshair(settings.social_accept_x,    settings.social_accept_y,    '5. Accept',        color_red(220))
        draw_crosshair(settings.social_teleport_x,  settings.social_teleport_y,  '6. Teleport (Tem)', color_white(220))
    end

    -- Stats overlay always visible
    stats.render()

    if not settings.enabled then return end

    -- Task HUD
    local task = task_manager.get_current_task()
    local social_status = (social.step ~= nil and social.step > 0) and ('social: ' .. (social.status or '')) or nil
    local msg = 'Path of Coin: ' .. (social_status or (task and (task.name .. (task.status ~= '' and ' (' .. task.status .. ')' or '')) or 'idle'))
    local x = get_screen_width() / 2 - (#msg * 5.5)
    graphics.text_2d(msg, vec2:new(x, 80), 20, color_white(255))

    -- Recent click markers
    local clicks, fade = social.get_recent_clicks()
    local now = get_time_since_inject()
    for _, c in ipairs(clicks) do
        local age   = now - c.t
        local alpha = math.max(0, math.min(255, math.floor(255 * (1 - age / fade))))
        local col   = color_yellow(alpha)
        graphics.circle_2d(vec2:new(c.x, c.y), 14, col, 2)
        graphics.circle_2d(vec2:new(c.x, c.y),  3, col, 2)
        graphics.text_2d(string.format('%s (%.1fs)', c.label, age),
            vec2:new(c.x + 18, c.y + 10), 13, col)
    end
end)

on_render_menu(function()
    gui.render(task_manager.get_current_task(), tracker)
end)

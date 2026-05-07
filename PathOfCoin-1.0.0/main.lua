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

local hang_last_task   = nil
local hang_last_time   = -1
local HANG_TIMEOUT     = 120.0  -- seconds on same task before force-firing social
local GOLD_MAX_RANGE   = 60.0   -- only pick up gold within this range of player
local idle_since       = -1
local IDLE_FIRE_DELAY  = 4.0    -- fire social after this many seconds of true idle in dungeon

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
            if ok and type(s) == 'table' and s.trigger_tasks then
                return
            end
        end
    end

    if world.is_in_dungeon() then

        -- 4s idle fallback: if social is idle, gold is done, and task manager has nothing to do, fire social
        if settings.use_social_connector and social.step == 0 and tracker.gold_pickup_done then
            local cur = task_manager.get_current_task()
            if cur == nil or cur.name == 'Idle' then
                if idle_since < 0 then
                    idle_since = now
                elseif (now - idle_since) >= IDLE_FIRE_DELAY then
                    console.print('[PathOfCoin] Idle fallback fired — no active task for ' .. IDLE_FIRE_DELAY .. 's')
                    idle_since = -1
                    social.start()
                end
            else
                idle_since = -1
            end
        else
            idle_since = -1
        end

        -- Global hang watchdog: only after route_done, if boss/gold phase hangs too long
        if settings.use_social_connector and social.step == 0 and tracker.route_done then
            local cur = task_manager.get_current_task()
            local cur_name = cur and cur.name or 'idle'
            if cur_name ~= hang_last_task then
                hang_last_task = cur_name
                hang_last_time = now
            elseif hang_last_time > 0 and (now - hang_last_time) >= HANG_TIMEOUT then
                console.print('[PathOfCoin] Hang watchdog fired on task: ' .. cur_name .. ' — firing social connector')
                hang_last_task = nil
                hang_last_time = -1
                social.start()
            end
        else
            hang_last_task = nil
            hang_last_time = -1
        end

        task_manager.execute_tasks()

        -- Track when boss_chest_done first became true so gold has time to land
        if tracker.boss_chest_done and tracker.boss_chest_time < 0 then
            tracker.boss_chest_time = now
        end

        -- Pick up gold on the floor before firing social connector (wait 3s for loot to settle)
        if tracker.boss_chest_done and not tracker.gold_pickup_done
           and (now - tracker.boss_chest_time) >= 3.0 then
            local player = get_local_player()
            if player then
                local player_pos = player:get_position()
                local closest_gold, closest_dist = nil, math.huge
                local ok, items = pcall(function() return actors_manager:get_all_items() end)
                if ok and type(items) == 'table' then
                    for _, item in ipairs(items) do
                        local is_gold = false
                        pcall(function() is_gold = loot_manager.is_gold(item) end)
                        if is_gold then
                            local dist = item:get_position():dist_to(player_pos)
                            if dist <= GOLD_MAX_RANGE and dist < closest_dist then
                                closest_gold = item
                                closest_dist = dist
                            end
                        end
                    end
                end

                if closest_gold then
                    local gold_pos = closest_gold:get_position()

                    -- Stuck detection: skip this piece after 3s
                    local stuck_key = string.format('%.1f_%.1f', gold_pos.x, gold_pos.y)
                    if tracker.gold_stuck_pos ~= stuck_key then
                        tracker.gold_stuck_pos  = stuck_key
                        tracker.gold_stuck_time = now
                    elseif (now - tracker.gold_stuck_time) >= 3.0 then
                        console.print('[PathOfCoin] Gold stuck timeout — skipping to next')
                        tracker.gold_stuck_pos  = nil
                        tracker.gold_stuck_time = -1
                        closest_gold = nil
                    end

                    if closest_gold then
                        if closest_dist <= 2.0 then
                            interact_object(closest_gold)
                        else
                            pathfinder.request_move(gold_pos)
                        end
                    end
                else
                    tracker.gold_pickup_done = true
                    console.print('[PathOfCoin] Gold pickup done — firing social connector')
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

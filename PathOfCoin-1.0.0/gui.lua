local plugin_label   = 'path_of_coin'
local plugin_version = '1.0.0'

local gui = {}
gui.plugin_label   = plugin_label
gui.plugin_version = plugin_version

local function cb(default, key)
    return checkbox:new(default, get_hash(plugin_label .. '_' .. key))
end

local function si(min, max, default, key)
    return slider_int:new(min, max, default, get_hash(plugin_label .. '_' .. key))
end

gui.elements = {
    main_tree    = tree_node:new(0),
    main_toggle  = cb(false, 'main_toggle'),

    -- Routing
    route_tree       = tree_node:new(1),
    batmobile_rush   = cb(false, 'batmobile_rush'),
    use_teleport     = cb(false, 'use_teleport'),
    open_chests      = cb(true,  'open_chests'),
    chest_range      = si(5,  30,  15, 'chest_range'),
    loot_wait        = si(1,  10,   1, 'loot_wait'),
    reset_wait       = si(1,  15,   5, 'reset_wait'),
    rush_mode        = cb(false, 'rush_mode'),

    -- Social connector
    social_tree            = tree_node:new(1),
    use_social_connector   = cb(false, 'use_social'),
    use_alfred             = cb(false, 'use_alfred'),
    show_click_points      = cb(false, 'show_clicks'),
    clear_wait             = si(1,  30,   8, 'clear_wait'),
    social_step_delay      = si(1,  10,   1, 'step_delay'),
    social_join_wait       = si(1,  15,   3, 'join_wait'),
    social_transfer_wait   = si(1,  15,   2, 'transfer_wait'),
    social_leave_wait      = si(1,  15,   2, 'leave_wait'),
    social_arrival_timeout = si(5,  120, 30, 'arrival_timeout'),
    social_post_teleport_wait = si(1, 30,  8, 'post_tp_wait'),
    social_watchdog        = si(10, 120, 60, 'watchdog'),

    -- Click coordinates
    clicks_tree      = tree_node:new(1),
    social_friend_x  = si(0, 3840, 960, 'friend_x'),
    social_friend_y  = si(0, 2160, 540, 'friend_y'),
    social_join_x    = si(0, 3840, 960, 'join_x'),
    social_join_y    = si(0, 2160, 600, 'join_y'),
    social_transfer_x = si(0, 3840, 960, 'transfer_x'),
    social_transfer_y = si(0, 2160, 650, 'transfer_y'),
    social_leave_x   = si(0, 3840, 960, 'leave_x'),
    social_leave_y   = si(0, 2160, 600, 'leave_y'),
    social_accept_x  = si(0, 3840, 960, 'accept_x'),
    social_accept_y  = si(0, 2160, 650, 'accept_y'),
    social_teleport_x = si(0, 3840, 960, 'teleport_x'),
    social_teleport_y = si(0, 2160, 650, 'teleport_y'),
}

gui.render = function(current_task, tracker)
    if not gui.elements.main_tree:push('Path of Coin | v' .. plugin_version) then return end

    gui.elements.main_toggle:render('Enable', 'Enable Path of Coin bot.')

    if gui.elements.route_tree:push('Routing') then
        gui.elements.batmobile_rush:render('Batmobile Rush', 'Use Batmobile to navigate straight to boss.')
        gui.elements.use_teleport:render('Sorcerer Teleport', 'Cast teleport while routing to boss (Sorcerer only).')
        gui.elements.open_chests:render('Open Chests', 'Open rare chests on the route.')
        gui.elements.chest_range:render('Chest Range (m)', 'How close a chest must be to stop for it.')
        gui.elements.loot_wait:render('Loot Wait (s)', 'Seconds to wait after opening a chest.')
        gui.elements.reset_wait:render('Reset Wait (s)', 'Seconds to wait after dungeon reset.')
        gui.elements.route_tree:pop()
    end

    if gui.elements.social_tree:push('Social Connector') then
        gui.elements.use_social_connector:render('Enable Social Connector', 'Automate party join/leave between runs.')
        gui.elements.use_alfred:render('Enable Alfred', 'Hand off to Alfred when inventory is full.')
        gui.elements.show_click_points:render('Show Click Crosshairs', 'Draw crosshairs on screen for each click point.')
        gui.elements.clear_wait:render('Clear Wait (s)', 'Seconds to wait after gold pickup before firing social connector.')
        gui.elements.social_step_delay:render('Step Delay (s)', 'Delay between each social menu step.')
        gui.elements.social_join_wait:render('Join Wait (s)', 'Seconds to wait after clicking Join Party.')
        gui.elements.social_transfer_wait:render('Transfer Wait (s)', 'Seconds to wait after clicking Transfer Now.')
        gui.elements.social_leave_wait:render('Leave Wait (s)', 'Seconds to wait after clicking Leave Party.')
        gui.elements.social_arrival_timeout:render('Arrival Timeout (s)', 'Seconds before retrying transfer if not arrived.')
        gui.elements.social_post_teleport_wait:render('Post-Teleport Wait (s)', 'Seconds to wait after teleport before leaving party.')
        gui.elements.social_watchdog:render('Watchdog Timeout (s)', 'Seconds any step can run before restarting sequence.')
        gui.elements.social_tree:pop()
    end

    if gui.elements.clicks_tree:push('Click Points') then
        render_text('1. Friend Name')
        gui.elements.social_friend_x:render('Friend X', '')
        gui.elements.social_friend_y:render('Friend Y', '')
        render_text('2. Join Party Button')
        gui.elements.social_join_x:render('Join X', '')
        gui.elements.social_join_y:render('Join Y', '')
        render_text('3. Transfer Now Button')
        gui.elements.social_transfer_x:render('Transfer X', '')
        gui.elements.social_transfer_y:render('Transfer Y', '')
        render_text('4. Leave Party Button')
        gui.elements.social_leave_x:render('Leave X', '')
        gui.elements.social_leave_y:render('Leave Y', '')
        render_text('5. Accept/Confirm Button')
        gui.elements.social_accept_x:render('Accept X', '')
        gui.elements.social_accept_y:render('Accept Y', '')
        render_text('6. Teleport Button (Temerity)')
        gui.elements.social_teleport_x:render('Teleport X', '')
        gui.elements.social_teleport_y:render('Teleport Y', '')
        gui.elements.clicks_tree:pop()
    end

    if current_task then
        render_text('Task: ' .. (current_task.name or 'none') .. ' — ' .. (current_task.status or ''))
    end
    if tracker then
        render_text('Route: ' .. tostring(tracker.route_done) ..
            ' | Boss: ' .. tostring(tracker.boss_dead) ..
            ' | Chest: ' .. tostring(tracker.boss_chest_done) ..
            ' | Gold: ' .. tostring(tracker.gold_pickup_done) ..
            ' | Party: ' .. tostring(tracker.left_party))
    end

    gui.elements.main_tree:pop()
end

return gui

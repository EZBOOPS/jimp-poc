local gui = {}

gui.plugin_version = '1.0.0'

local menu = menu or {}

gui.elements = {
    main_toggle         = menu.checkbox:new(false, get_hash('poc_main_toggle')),
    rush_mode           = menu.checkbox:new(false, get_hash('poc_rush_mode')),
    batmobile_rush      = menu.checkbox:new(false, get_hash('poc_batmobile_rush')),
    use_teleport        = menu.checkbox:new(false, get_hash('poc_use_teleport')),
    open_chests         = menu.checkbox:new(true,  get_hash('poc_open_chests')),
    loot_wait           = menu.slider_float:new(0.5, 3.0, get_hash('poc_loot_wait'), 1.0),
    reset_wait          = menu.slider_float:new(1.0, 15.0, get_hash('poc_reset_wait'), 5.0),
    chest_range         = menu.slider_float:new(5.0, 30.0, get_hash('poc_chest_range'), 15.0),
    clear_wait          = menu.slider_float:new(1.0, 20.0, get_hash('poc_clear_wait'), 8.0),
    use_social_connector = menu.checkbox:new(false, get_hash('poc_use_social')),
    use_alfred          = menu.checkbox:new(false, get_hash('poc_use_alfred')),
    show_click_points   = menu.checkbox:new(false, get_hash('poc_show_clicks')),

    -- Social timing sliders
    social_step_delay        = menu.slider_float:new(0.5, 5.0,  get_hash('poc_step_delay'),       1.0),
    social_join_wait         = menu.slider_float:new(1.0, 10.0, get_hash('poc_join_wait'),         3.0),
    social_transfer_wait     = menu.slider_float:new(1.0, 10.0, get_hash('poc_transfer_wait'),     2.0),
    social_leave_wait        = menu.slider_float:new(1.0, 10.0, get_hash('poc_leave_wait'),        2.0),
    social_arrival_timeout   = menu.slider_float:new(5.0, 60.0, get_hash('poc_arrival_timeout'),  30.0),
    social_post_teleport_wait = menu.slider_float:new(1.0, 20.0, get_hash('poc_post_tp_wait'),    8.0),
    social_watchdog          = menu.slider_float:new(10.0, 120.0, get_hash('poc_watchdog'),       60.0),

    -- Click point coordinates
    social_friend_x     = menu.slider_int:new(0, 3840, get_hash('poc_friend_x'),    960),
    social_friend_y     = menu.slider_int:new(0, 2160, get_hash('poc_friend_y'),    540),
    social_join_x       = menu.slider_int:new(0, 3840, get_hash('poc_join_x'),      960),
    social_join_y       = menu.slider_int:new(0, 2160, get_hash('poc_join_y'),      600),
    social_transfer_x   = menu.slider_int:new(0, 3840, get_hash('poc_transfer_x'),  960),
    social_transfer_y   = menu.slider_int:new(0, 2160, get_hash('poc_transfer_y'),  650),
    social_leave_x      = menu.slider_int:new(0, 3840, get_hash('poc_leave_x'),     960),
    social_leave_y      = menu.slider_int:new(0, 2160, get_hash('poc_leave_y'),     600),
    social_accept_x     = menu.slider_int:new(0, 3840, get_hash('poc_accept_x'),    960),
    social_accept_y     = menu.slider_int:new(0, 2160, get_hash('poc_accept_y'),    650),
    social_teleport_x   = menu.slider_int:new(0, 3840, get_hash('poc_teleport_x'),  960),
    social_teleport_y   = menu.slider_int:new(0, 2160, get_hash('poc_teleport_y'),  650),
}

gui.render = function(current_task, tracker)
    if menu.begin_menu('Path of Coin') then

        menu.checkbox('Enable', gui.elements.main_toggle)
        menu.separator()

        if menu.collapsing_header('Routing') then
            menu.checkbox('Batmobile Rush to Boss', gui.elements.batmobile_rush)
            menu.checkbox('Sorcerer Teleport', gui.elements.use_teleport)
            menu.checkbox('Open Chests on Route', gui.elements.open_chests)
            menu.slider_float('Chest Scan Range', gui.elements.chest_range)
            menu.slider_float('Loot Wait (s)', gui.elements.loot_wait)
        end

        if menu.collapsing_header('Social Connector') then
            menu.checkbox('Enable Social Connector', gui.elements.use_social_connector)
            menu.checkbox('Enable Alfred Integration', gui.elements.use_alfred)
            menu.separator()
            menu.slider_float('Clear Wait (s)', gui.elements.clear_wait)
            menu.slider_float('Step Delay (s)', gui.elements.social_step_delay)
            menu.slider_float('Join Wait (s)', gui.elements.social_join_wait)
            menu.slider_float('Transfer Wait (s)', gui.elements.social_transfer_wait)
            menu.slider_float('Leave Wait (s)', gui.elements.social_leave_wait)
            menu.slider_float('Arrival Timeout (s)', gui.elements.social_arrival_timeout)
            menu.slider_float('Post-Teleport Wait (s)', gui.elements.social_post_teleport_wait)
            menu.slider_float('Watchdog Timeout (s)', gui.elements.social_watchdog)
        end

        if menu.collapsing_header('Click Points') then
            menu.checkbox('Show Click Point Crosshairs', gui.elements.show_click_points)
            menu.separator()
            menu.text('1. Friend Name')
            menu.slider_int('Friend X', gui.elements.social_friend_x)
            menu.slider_int('Friend Y', gui.elements.social_friend_y)
            menu.text('2. Join Party Button')
            menu.slider_int('Join X', gui.elements.social_join_x)
            menu.slider_int('Join Y', gui.elements.social_join_y)
            menu.text('3. Transfer Now Button')
            menu.slider_int('Transfer X', gui.elements.social_transfer_x)
            menu.slider_int('Transfer Y', gui.elements.social_transfer_y)
            menu.text('4. Leave Party Button')
            menu.slider_int('Leave X', gui.elements.social_leave_x)
            menu.slider_int('Leave Y', gui.elements.social_leave_y)
            menu.text('5. Accept/Confirm Button')
            menu.slider_int('Accept X', gui.elements.social_accept_x)
            menu.slider_int('Accept Y', gui.elements.social_accept_y)
            menu.text('6. Teleport Button (Temerity)')
            menu.slider_int('Teleport X', gui.elements.social_teleport_x)
            menu.slider_int('Teleport Y', gui.elements.social_teleport_y)
        end

        if current_task and menu.collapsing_header('Status') then
            menu.text('Task: ' .. (current_task.name or 'none'))
            menu.text('Status: ' .. (current_task.status or ''))
            if tracker then
                menu.text('Route done: ' .. tostring(tracker.route_done))
                menu.text('Boss dead: ' .. tostring(tracker.boss_dead))
                menu.text('Chest done: ' .. tostring(tracker.boss_chest_done))
                menu.text('Gold done: ' .. tostring(tracker.gold_pickup_done))
                menu.text('Left party: ' .. tostring(tracker.left_party))
            end
        end

        menu.end_menu()
    end
end

return gui

local tracker = {
    chests_opened         = 0,
    run_count             = 0,
    interact_time         = -1,
    interact_cooldown     = 2.0,
    last_interact_attempt = nil,
    reset_time            = -1,
    enter_time            = -1,
    route_done            = false,
    boss_dead             = false,
    boss_chest_done       = false,
    boss_chest_time       = -1,
    goblins_phase         = false,
    boss_died_time        = -1,
    gold_pickup_done      = false,
    gold_stuck_pos        = nil,
    gold_stuck_time       = -1,
    left_party            = false,
}

tracker.reset_run = function()
    tracker.chests_opened         = 0
    tracker.interact_time         = -1
    tracker.last_interact_attempt = nil
    tracker.reset_time            = -1
    tracker.enter_time            = -1
    tracker.route_done            = false
    tracker.boss_dead             = false
    tracker.boss_chest_done       = false
    tracker.boss_chest_time       = -1
    tracker.goblins_phase         = false
    tracker.boss_died_time        = -1
    tracker.gold_pickup_done      = false
    tracker.gold_stuck_pos        = nil
    tracker.gold_stuck_time       = -1
    tracker.left_party            = false
end

return tracker

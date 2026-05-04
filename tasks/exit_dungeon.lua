local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local world    = require 'core.world'

local RETRY_INTERVAL = 10.0  -- seconds before firing leave_dungeon() again

local task = {
    name       = 'exit_dungeon',
    status     = 'idle',
    leave_time = -1,
    retries    = 0,
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

-- Reset state each run
local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    task.leave_time = -1
    task.retries    = 0
end

return task

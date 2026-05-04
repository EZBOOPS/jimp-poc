local tracker = require 'core.tracker'
local world   = require 'core.world'

local plugin_label = 'gem_farmer'

local task = {
    name    = 'alfred',
    status  = 'idle',
    running = false,
}

local function on_alfred_done()
    task.running = false
    task.status  = 'idle'
    console.print('[GemFarmer] Alfred finished — resuming farming')
end

-- Reset if tracker clears between runs
local _orig_reset = tracker.reset_run
tracker.reset_run = function()
    _orig_reset()
    if task.running then
        if AlfredTheButlerPlugin then AlfredTheButlerPlugin.pause(plugin_label) end
        task.running = false
        task.status  = 'idle'
    end
end

task.shouldExecute = function()
    -- Keep executing until Alfred calls the done callback
    if task.running then return true end

    -- Only trigger when outside the dungeon
    if not world.is_outside() then return false end
    if not AlfredTheButlerPlugin then return false end

    local status = AlfredTheButlerPlugin.get_status()
    if not status or not status.enabled then return false end

    return status.need_trigger or status.inventory_full or status.need_repair
end

task.Execute = function()
    if not task.running then
        task.running = true
        AlfredTheButlerPlugin.resume()
        AlfredTheButlerPlugin.trigger_tasks_with_teleport(plugin_label, on_alfred_done)
        task.status = 'triggered'
        console.print('[GemFarmer] Yielding to Alfred for inventory management')
        return
    end
    task.status = 'waiting for alfred to finish'
end

return task

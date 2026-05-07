local task_manager = {}

local tasks        = {}
local last_tick    = -1
local tick_rate    = 0.05
local current_task = { name = 'Idle', status = 'idle' }

task_manager.register_task = function(task)
    table.insert(tasks, task)
end

task_manager.execute_tasks = function()
    local now = get_time_since_inject()
    if now - last_tick < tick_rate then return end
    last_tick = now

    for _, task in ipairs(tasks) do
        if task.shouldExecute() then
            current_task = task
            task:Execute()
            return
        end
    end
    current_task = { name = 'Idle', status = 'idle' }
end

task_manager.get_current_task = function()
    return current_task
end

local task_files = {
    'run_route',
    'boss_room',
    'idle',
}

for _, name in ipairs(task_files) do
    local task = require('tasks.' .. name)
    task_manager.register_task(task)
end

return task_manager

local world = require 'core.world'

local task = {
    name   = 'idle',
    status = 'waiting for dungeon',
}

task.shouldExecute = function()
    return true
end

task.Execute = function()
    if not world.is_in_dungeon() then
        task.status = 'not in dungeon (world ID: 1276972031)'
    else
        task.status = 'idle'
    end
end

return task

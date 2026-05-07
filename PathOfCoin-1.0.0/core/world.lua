local world_module = {}

local function get_id()
    local ok, world = pcall(get_current_world)
    if not ok or not world then return 0 end
    local ok2, id = pcall(function() return world:get_world_id() end)
    if not ok2 then return 0 end
    return id
end

local WORLD_DUNGEON  = 1276972031
local WORLD_TEMERITY = 4156639130

world_module.is_in_dungeon   = function() return get_id() == WORLD_DUNGEON  end
world_module.is_in_temerity  = function() return get_id() == WORLD_TEMERITY end
world_module.get_world_id    = function() return get_id() end

return world_module

local Missions = {}

local activeMission = nil
local missionBlip = nil

function Missions.Start()
    if activeMission then
        lib.notify({
            title = locale('mission_already_active'),
            type = 'error'
        })
        return
    end
    
    local missionData = lib.callback.await('mechanic:server:getMission', false)
    if missionData then
        activeMission = missionData
        
        -- Create mission blip
        missionBlip = AddBlipForCoord(activeMission.coords.x, activeMission.coords.y, activeMission.coords.z)
        SetBlipSprite(missionBlip, Config.Blips.mission.sprite)
        SetBlipColour(missionBlip, Config.Blips.mission.color)
        SetBlipScale(missionBlip, Config.Blips.mission.scale)
        SetBlipDisplay(missionBlip, Config.Blips.mission.display)
        SetBlipRoute(missionBlip, true)
        
        lib.notify({
            title = locale('mission_started'),
            description = activeMission.description,
            type = 'success'
        })
    end
end

function Missions.Complete(success)
    if success then
        lib.notify({
            title = locale('mission_complete'),
            type = 'success'
        })
    else
        lib.notify({
            title = locale('mission_failed'),
            type = 'error'
        })
    end
    
    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end
    activeMission = nil
end

-- Event: Triggered when reaching mission location
RegisterNetEvent('mechanic:client:missionAccomplished', function(success)
    Missions.Complete(success)
end)

-- The mission start is handled through the mechanic menu

return Missions

local Missions = {}

local activeMission = nil
local missionBlip = nil
local missionPoint = nil

local function clearMissionTargets()
    if missionPoint then
        missionPoint:remove()
        missionPoint = nil
    end
end

local function isMissionRepairComplete(mission)
    if not mission or not mission.coords then return false end
    local radius = mission.radius or Config.NPCMissions.completionRadius or 10.0
    local vehicle = lib.getClosestVehicle(mission.coords, radius, false)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end

    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local requiredEngine = Config.NPCMissions.requiredEngineHealth or 900.0
    local requiredBody = Config.NPCMissions.requiredBodyHealth or 900.0

    return engineHealth >= requiredEngine and bodyHealth >= requiredBody
end

local function setActiveMission(missionData)
    if not missionData or activeMission then return end

    activeMission = missionData

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

    clearMissionTargets()
    missionPoint = lib.points.new({
        coords = activeMission.coords,
        distance = activeMission.radius or Config.NPCMissions.completionRadius or 10.0,
        mission = activeMission
    })

    function missionPoint:nearby()
        if self.currentDistance < 2.0 then
            lib.showTextUI(locale('mission_press_complete'))
            if IsControlJustPressed(0, 38) then
                if isMissionRepairComplete(self.mission) then
                    lib.hideTextUI()
                    TriggerServerEvent('mechanic:server:completeMission', true)
                else
                    lib.notify({
                        title = locale('mission_repair_required'),
                        type = 'error'
                    })
                end
            end
        end
    end

    function missionPoint:onExit()
        lib.hideTextUI()
    end
end

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
        setActiveMission(missionData)
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
    clearMissionTargets()
end

RegisterNetEvent('mechanic:client:newMission', function(missionData)
    setActiveMission(missionData)
end)

-- Event: Triggered when reaching mission location
RegisterNetEvent('mechanic:client:missionAccomplished', function(success)
    Missions.Complete(success)
end)

-- The mission start is handled through the mechanic menu

return Missions

local Missions = {}

local activeMissions = {}
local missionCounter = 0

local function removeMissionForPlayer(playerId)
    if not playerId then return end

    local mission = activeMissions[playerId]
    if mission then
        activeMissions[playerId] = nil
    end

    return mission
end

-- Generate a new mission
function Missions.Generate(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false end
    
    local locations = Config.NPCMissions.locations
    local location = locations[math.random(#locations)]
    local vehicleModel = Config.NPCMissions.vehicles[math.random(#Config.NPCMissions.vehicles)]
    
    missionCounter = missionCounter + 1

    local mission = {
        coords = vector3(location.coords.x, location.coords.y, location.coords.z),
        model = vehicleModel,
        payout = math.random(Config.NPCMissions.payouts.repair.min, Config.NPCMissions.payouts.repair.max),
        description = locale('repair_mission_description', vehicleModel),
        id = ('mission_%d'):format(missionCounter),
        player = source,
        startedAt = os.time()
    }

    activeMissions[source] = mission
    TriggerClientEvent('mechanic:client:newMission', source, mission)
    return mission
end

-- Complete a mission
function Missions.Complete(source, success)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false end
    
    local mission = removeMissionForPlayer(source)
    if not mission then return false end

    if success then
        Player.Functions.AddMoney('bank', mission.payout)
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('mission_complete'),
            description = locale('earned_money', mission.payout),
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('mission_failed'),
            type = 'error'
        })
    end

    return true
end

-- Events
RegisterNetEvent('mechanic:server:completeMission', function(success)
    Missions.Complete(source, success)
end)

AddEventHandler('playerDropped', function()
    removeMissionForPlayer(source)
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(playerId)
    removeMissionForPlayer(playerId or source)
end)

-- Callbacks
lib.callback.register('mechanic:server:getMission', function(source)
    return Missions.Generate(source)
end)

return Missions

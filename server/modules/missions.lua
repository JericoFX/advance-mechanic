local Missions = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

local activeMissions = {}
local missionCounter = 0
local missionCooldowns = {}

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
    local Player = Framework.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false end

    if not Config.NPCMissions.enabled then
        return false
    end

    if not Validation.CheckRateLimit(source, 'mission_request', Config.Security.rateLimits.missionRequestMs) then
        return false
    end

    if activeMissions[source] then
        return false
    end

    local lastMissionAt = missionCooldowns[source] or 0
    if (os.time() - lastMissionAt) < Config.NPCMissions.cooldown then
        return false
    end
    
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
        startedAt = os.time(),
        radius = location.radius or Config.NPCMissions.completionRadius
    }

    activeMissions[source] = mission
    missionCooldowns[source] = os.time()
    TriggerClientEvent('mechanic:client:newMission', source, mission)
    return mission
end

-- Complete a mission
function Missions.Complete(source, success)
    local Player = Framework.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false end

    if not Validation.CheckRateLimit(source, 'mission_complete', Config.Security.rateLimits.missionCompleteMs) then
        return false
    end
    
    local mission = activeMissions[source]
    if not mission then return false end

    if success == true then
        local minDuration = Config.NPCMissions.minDuration or 0
        if os.time() - (mission.startedAt or 0) < minDuration then
            return false
        end

        local radius = mission.radius or Config.NPCMissions.completionRadius
        if not Validation.IsPlayerNearCoords(source, mission.coords, radius) then
            return false
        end
    end

    removeMissionForPlayer(source)

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

    TriggerClientEvent('mechanic:client:missionAccomplished', source, success == true)

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

RegisterNetEvent('esx:playerDropped', function(playerId)
    removeMissionForPlayer(playerId or source)
end)

-- Callbacks
lib.callback.register('mechanic:server:getMission', function(source)
    return Missions.Generate(source)
end)

return Missions

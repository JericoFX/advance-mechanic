local Missions = {}

local activeMissions = {}

-- Generate a new mission
function Missions.Generate(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false end
    
    local locations = Config.NPCMissions.locations
    local location = locations[math.random(#locations)]
    local vehicleModel = Config.NPCMissions.vehicles[math.random(#Config.NPCMissions.vehicles)]
    
    local mission = {
        coords = vector3(location.coords.x, location.coords.y, location.coords.z),
        model = vehicleModel,
        payout = math.random(Config.NPCMissions.payouts.repair.min, Config.NPCMissions.payouts.repair.max),
        description = locale('repair_mission_description', vehicleModel)
    }
    
    table.insert(activeMissions, mission)
    TriggerClientEvent('mechanic:client:newMission', source, mission)
    return mission
end

-- Complete a mission
function Missions.Complete(source, success)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false end
    
    for index, mission in ipairs(activeMissions) do
        if mission.player == source then
            table.remove(activeMissions, index)
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
            break
        end
    end
end

-- Events
RegisterNetEvent('mechanic:server:completeMission', function(success)
    Missions.Complete(source, success)
end)

-- Callbacks
lib.callback.register('mechanic:server:getMission', function(source)
    return Missions.Generate(source)
end)

return Missions

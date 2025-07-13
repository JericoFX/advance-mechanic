local Tuning = {}

lib.callback.register('mechanic:server:applyPerformanceMod', function(source, price, modType, level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return false end
    
    if Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    -- Check if player has enough money
    if Player.Functions.RemoveMoney('cash', price) then
        -- Add to shop revenue if in shop
        -- TODO: Add shop revenue tracking
        
        return true
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

lib.callback.register('mechanic:server:applyVisualMod', function(source, price, modType, modIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return false end
    
    if Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    if Player.Functions.RemoveMoney('cash', price) then
        return true
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

lib.callback.register('mechanic:server:installNitro', function(source, netId, capacity, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return false end
    
    if Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    if Player.Functions.RemoveMoney('cash', price) then
        -- Sync nitro state to all players
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(vehicle) then
            Entity(vehicle).state:set('hasNitro', true, true)
            Entity(vehicle).state:set('nitroCapacity', capacity, true)
            Entity(vehicle).state:set('nitroLevel', 100, true)
        end
        
        return true
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

-- Save vehicle properties after modifications
RegisterNetEvent('mechanic:server:saveVehicleProps', function(netId, props)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return end
    
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    
    -- Update vehicle properties in database
    MySQL.update('UPDATE player_vehicles SET props = ? WHERE plate = ?', {
        json.encode(props),
        plate
    })
    
    -- Sync to all players
    TriggerClientEvent('mechanic:client:syncVehicleProperties', -1, netId, props)
end)

return Tuning

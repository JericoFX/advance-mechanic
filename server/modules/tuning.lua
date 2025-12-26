local Tuning = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

lib.callback.register('mechanic:server:applyPerformanceMod', function(source, netId, modType, level)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        return false
    end

    local price = Validation.CalculatePerformanceModPrice(modType, level)
    if not price then
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, price) then
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

lib.callback.register('mechanic:server:applyVisualMod', function(source, netId, modType, modIndex)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        return false
    end

    local price = Validation.CalculateVisualModPrice(modType, modIndex)
    if price == nil then
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, price) then
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
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        return false
    end

    local configuredPrice = Config.Tuning.nitro.install[capacity]
    if not configuredPrice then
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, configuredPrice) then
        -- Sync nitro state to all players
        Entity(vehicle).state:set('hasNitro', true, true)
        Entity(vehicle).state:set('nitroCapacity', capacity, true)
        Entity(vehicle).state:set('nitroLevel', 100, true)
        
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
    local Player = Framework.GetPlayer(src)
    
    if not Player or not Validation.IsMechanic(Player) then return end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not DoesEntityExist(vehicle) then return end
    if not Validation.IsPlayerNearEntity(src, vehicle, 10.0) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then return end

    local sanitizedProps = Validation.SanitizeProps(props)
    if not sanitizedProps then return end
    
    -- Update vehicle properties in database
    MySQL.update('UPDATE player_vehicles SET props = ? WHERE plate = ?', {
        json.encode(sanitizedProps),
        plate
    })
    
    -- Sync to all players
    TriggerClientEvent('mechanic:client:syncVehicleProperties', -1, netId, sanitizedProps)
end)

return Tuning

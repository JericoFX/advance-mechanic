local Tuning = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

lib.callback.register('mechanic:server:applyPerformanceMod', function(source, netId, modType, level)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'tuning_performance', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'tuning_performance', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'tuning_performance', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'tuning_performance', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        Validation.LogDenied(src, 'tuning_performance', 'vehicle_unowned')
        return false
    end

    local modTypeValue = tonumber(modType)
    local levelValue = tonumber(level)
    if modTypeValue == nil or levelValue == nil then
        Validation.LogDenied(src, 'tuning_performance', 'invalid_mod_params')
        return false
    end

    local price = Validation.CalculatePerformanceModPrice(modTypeValue, levelValue)
    if not price then
        Validation.LogDenied(src, 'tuning_performance', 'invalid_price')
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
        Validation.LogDenied(src, 'tuning_visual', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'tuning_visual', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'tuning_visual', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'tuning_visual', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        Validation.LogDenied(src, 'tuning_visual', 'vehicle_unowned')
        return false
    end

    local modTypeValue = tonumber(modType)
    local modIndexValue = tonumber(modIndex)
    if modTypeValue == nil or modIndexValue == nil then
        Validation.LogDenied(src, 'tuning_visual', 'invalid_mod_params')
        return false
    end

    local price = Validation.CalculateVisualModPrice(modTypeValue, modIndexValue)
    if price == nil then
        Validation.LogDenied(src, 'tuning_visual', 'invalid_price')
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
        Validation.LogDenied(src, 'tuning_nitro', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'tuning_nitro', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'tuning_nitro', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'tuning_nitro', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        Validation.LogDenied(src, 'tuning_nitro', 'vehicle_unowned')
        return false
    end

    local capacityValue = tonumber(capacity)
    if capacityValue == nil then
        Validation.LogDenied(src, 'tuning_nitro', 'invalid_capacity')
        return false
    end

    local configuredPrice = Config.Tuning.nitro.install[capacityValue]
    if not configuredPrice then
        Validation.LogDenied(src, 'tuning_nitro', 'capacity_not_configured')
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, configuredPrice) then
        -- Sync nitro state to all players
        Entity(vehicle).state:set('hasNitro', true, true)
        Entity(vehicle).state:set('nitroCapacity', capacityValue, true)
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
    if not Validation.CheckRateLimit(src, 'vehicle_props', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'vehicle_props', 'rate_limited')
        return
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not DoesEntityExist(vehicle) then return end
    if not Validation.IsPlayerNearEntity(src, vehicle, 10.0) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwnedBy(plate, Player.PlayerData.citizenid)
    if not isOwned and not Validation.IsAdmin(src) then return end

    local sanitizedProps = Validation.SanitizeProps(props)
    if not sanitizedProps then
        Validation.LogDenied(src, 'vehicle_props', 'invalid_props')
        return
    end
    
    -- Update vehicle properties in database
    MySQL.update('UPDATE player_vehicles SET props = ? WHERE plate = ?', {
        json.encode(sanitizedProps),
        plate
    })
    
    -- Sync to all players
    TriggerClientEvent('mechanic:client:syncVehicleProperties', -1, netId, sanitizedProps)
end)

return Tuning

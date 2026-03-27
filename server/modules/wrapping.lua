local Wrapping = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

---@param material string
---@return boolean
local function isValidMaterial(material)
    return Config.Wrapping.materials[material] ~= nil
end

---@param colorIndex number
---@return boolean
local function isValidColorIndex(colorIndex)
    return type(colorIndex) == 'number' and colorIndex >= 0 and colorIndex <= 160
end

---@param material string
---@return number
local function calculatePrice(material)
    local matData = Config.Wrapping.materials[material]
    local mult = matData and matData.priceMultiplier or 1.0
    return math.floor(Config.Wrapping.basePrice * mult)
end

---@param shopId number|nil
---@return table
local function getWrapCatalog(shopId)
    local query = 'SELECT * FROM wrap_catalog WHERE shop_id IS NULL'
    local params = {}
    if shopId then
        query = query .. ' OR shop_id = ?'
        params = { shopId }
    end
    local result = MySQL.query.await(query, params)
    return result or {}
end

lib.callback.register('mechanic:server:getWrapCatalog', function(source, shopId)
    local Player = Framework.GetPlayer(source)
    if not Player then return {} end
    if not Validation.IsMechanic(Player) then return {} end
    return getWrapCatalog(shopId)
end)

lib.callback.register('mechanic:server:applyWrap', function(source, netId, primaryColor, secondaryColor, material, liveryIndex)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'wrapping', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'wrapping', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'wrapping', 'rate_limited')
        return false
    end

    if not isValidMaterial(material) then
        Validation.LogDenied(src, 'wrapping', 'invalid_material')
        return false
    end

    if primaryColor ~= -1 and not isValidColorIndex(primaryColor) then
        Validation.LogDenied(src, 'wrapping', 'invalid_primary_color')
        return false
    end

    if secondaryColor ~= -1 and not isValidColorIndex(secondaryColor) then
        Validation.LogDenied(src, 'wrapping', 'invalid_secondary_color')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.Wrapping.maxDistance) then
        Validation.LogDenied(src, 'wrapping', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'wrapping', 'vehicle_unowned')
        return false
    end

    local price = calculatePrice(material)
    local account = Config.Economy.payWithCash and 'cash' or 'bank'

    if not Player.Functions.RemoveMoney(account, price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('wrap_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local matData = Config.Wrapping.materials[material]
    local props = {}

    if primaryColor >= 0 then
        props.color1 = primaryColor
    end
    if secondaryColor >= 0 then
        props.color2 = secondaryColor
    end

    if matData then
        props.paintType1 = matData.paintType
        props.paintType2 = matData.paintType
        if matData.pearlescent and primaryColor >= 0 then
            props.pearlescentColor = primaryColor
        end
    end

    local numericLivery = tonumber(liveryIndex)
    if numericLivery and numericLivery >= 0 then
        props.modLivery = numericLivery
    end

    lib.setVehicleProperties(vehicle, props)

    local vehicleCoords = GetEntityCoords(vehicle)
    local vehNetId = NetworkGetNetworkIdFromEntity(vehicle)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(playerId))
        if ped and DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            if #(playerCoords - vehicleCoords) < 300.0 then
                TriggerClientEvent('mechanic:client:syncVehicleProperties', tonumber(playerId), vehNetId, props)
            end
        end
    end

    return true
end)

lib.callback.register('mechanic:server:applyWrapCatalog', function(source, netId, catalogId)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'wrapping', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'wrapping_catalog', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'wrapping_catalog', 'rate_limited')
        return false
    end

    local numericId = tonumber(catalogId)
    if not numericId or numericId < 1 then
        Validation.LogDenied(src, 'wrapping_catalog', 'invalid_catalog_id')
        return false
    end

    local result = MySQL.query.await('SELECT * FROM wrap_catalog WHERE id = ?', { numericId })
    if not result or not result[1] then
        Validation.LogDenied(src, 'wrapping_catalog', 'catalog_not_found')
        return false
    end

    local catalogEntry = result[1]

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.Wrapping.maxDistance) then
        Validation.LogDenied(src, 'wrapping_catalog', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'wrapping_catalog', 'vehicle_unowned')
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, catalogEntry.price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('wrap_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local props = {
        color1 = catalogEntry.primary_color,
        color2 = catalogEntry.secondary_color,
        paintType1 = catalogEntry.paint_type,
        paintType2 = catalogEntry.paint_type
    }

    if catalogEntry.pearlescent_color then
        props.pearlescentColor = catalogEntry.pearlescent_color
    end

    lib.setVehicleProperties(vehicle, props)

    local vehicleCoords = GetEntityCoords(vehicle)
    local vehNetId = NetworkGetNetworkIdFromEntity(vehicle)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(playerId))
        if ped and DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            if #(playerCoords - vehicleCoords) < 300.0 then
                TriggerClientEvent('mechanic:client:syncVehicleProperties', tonumber(playerId), vehNetId, props)
            end
        end
    end

    return true
end)

return Wrapping

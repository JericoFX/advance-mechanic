local PaintBooth = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

---@param paintType string
---@return boolean
local function isValidPaintType(paintType)
    return Config.PaintBooth.priceMultipliers[paintType] ~= nil
end

---@param colorIndex number
---@return boolean
local function isValidColorIndex(colorIndex)
    return type(colorIndex) == 'number' and colorIndex >= 0 and colorIndex <= 160
end

---@param paintType string
---@return number
local function calculatePrice(paintType)
    local mult = Config.PaintBooth.priceMultipliers[paintType] or 1.0
    return math.floor(Config.PaintBooth.basePrice * mult)
end

lib.callback.register('mechanic:server:applyPaint', function(source, netId, paintType, colorIndex, pearlIndex)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'paint_booth', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'paint_booth', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'paint_booth', 'rate_limited')
        return false
    end

    if not isValidPaintType(paintType) then
        Validation.LogDenied(src, 'paint_booth', 'invalid_paint_type')
        return false
    end

    if paintType ~= 'chrome' and not isValidColorIndex(colorIndex) then
        Validation.LogDenied(src, 'paint_booth', 'invalid_color')
        return false
    end

    if paintType == 'pearlescent' and not isValidColorIndex(pearlIndex) then
        Validation.LogDenied(src, 'paint_booth', 'invalid_pearl_color')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.PaintBooth.maxDistance) then
        Validation.LogDenied(src, 'paint_booth', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'paint_booth', 'vehicle_unowned')
        return false
    end

    local price = calculatePrice(paintType)
    local account = Config.Economy.payWithCash and 'cash' or 'bank'

    if not Player.Functions.RemoveMoney(account, price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('paint_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local props = {}
    if paintType == 'chrome' then
        props.color1 = 120
        props.color2 = 120
    elseif paintType == 'pearlescent' then
        props.color1 = colorIndex
        props.color2 = colorIndex
        props.pearlescentColor = pearlIndex
    else
        props.color1 = colorIndex
        props.color2 = colorIndex
    end

    if paintType == 'matte' then
        props.paintType1 = 3
        props.paintType2 = 3
    elseif paintType == 'metallic' then
        props.paintType1 = 0
        props.paintType2 = 0
    elseif paintType == 'standard' then
        props.paintType1 = 0
        props.paintType2 = 0
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

return PaintBooth

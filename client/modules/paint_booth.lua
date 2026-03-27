local PaintBooth = {}

---@type number|nil
local activeVehicle = nil
---@type table|nil
local originalProps = nil
---@type boolean
local nuiOpen = false

---@param vehicle number
---@return table
local function saveOriginalColors(vehicle)
    return {
        color1 = GetVehicleColours(vehicle),
        color2 = select(2, GetVehicleColours(vehicle)),
        pearlescentColor = GetVehicleExtraColours(vehicle),
        paintType1 = GetVehicleModColor_1(vehicle),
        paintType2 = GetVehicleModColor_2(vehicle)
    }
end

---@param vehicle number
---@param props table
local function restoreColors(vehicle, props)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleColours(vehicle, props.color1, props.color2)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, props.pearlescentColor or pearl, wheel)
end

---@param vehicle number
---@param paintType string
---@param colorIndex number
---@param pearlIndex number
local function previewPaint(vehicle, paintType, colorIndex, pearlIndex)
    if not DoesEntityExist(vehicle) then return end

    if paintType == 'chrome' then
        SetVehicleColours(vehicle, 120, 120)
    elseif paintType == 'pearlescent' then
        SetVehicleColours(vehicle, colorIndex, colorIndex)
        if pearlIndex >= 0 then
            local _, wheel = GetVehicleExtraColours(vehicle)
            SetVehicleExtraColours(vehicle, pearlIndex, wheel)
        end
    elseif paintType == 'matte' then
        SetVehicleColours(vehicle, colorIndex, colorIndex)
        SetVehicleModColor_1(vehicle, colorIndex, 3)
        SetVehicleModColor_2(vehicle, colorIndex, 3)
    elseif paintType == 'metallic' then
        SetVehicleColours(vehicle, colorIndex, colorIndex)
        SetVehicleModColor_1(vehicle, colorIndex, 0)
        SetVehicleModColor_2(vehicle, colorIndex, 0)
    else
        SetVehicleColours(vehicle, colorIndex, colorIndex)
    end
end

local function closeNUI()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    if activeVehicle and originalProps and DoesEntityExist(activeVehicle) then
        restoreColors(activeVehicle, originalProps)
    end

    activeVehicle = nil
    originalProps = nil
end

---@param vehicle number
function PaintBooth.Open(vehicle)
    if not Config.PaintBooth.enabled then return end
    if not DoesEntityExist(vehicle) then return end
    if nuiOpen then return end

    activeVehicle = vehicle
    originalProps = saveOriginalColors(vehicle)
    nuiOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        basePrice = Config.PaintBooth.basePrice,
        multipliers = Config.PaintBooth.priceMultipliers
    })
end

RegisterNUICallback('paintPreview', function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) then
        previewPaint(activeVehicle, data.type, data.colorIndex, data.pearlIndex or -1)
    end
    cb('ok')
end)

RegisterNUICallback('paintConfirm', function(data, cb)
    if not activeVehicle or not DoesEntityExist(activeVehicle) then
        closeNUI()
        cb('ok')
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(activeVehicle)
    local success = lib.callback.await('mechanic:server:applyPaint', false,
        netId, data.type, data.colorIndex, data.pearlIndex or -1)

    if success then
        lib.notify({ title = locale('paint_applied'), type = 'success' })
        originalProps = nil
    else
        if originalProps then
            restoreColors(activeVehicle, originalProps)
        end
    end

    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    activeVehicle = nil
    originalProps = nil
    cb('ok')
end)

RegisterNUICallback('paintCancel', function(_, cb)
    closeNUI()
    lib.notify({ title = locale('paint_cancelled'), type = 'info' })
    cb('ok')
end)

return PaintBooth

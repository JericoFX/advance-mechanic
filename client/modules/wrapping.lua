local Wrapping = {}

---@type number|nil
local activeVehicle = nil
---@type table|nil
local originalProps = nil
---@type boolean
local nuiOpen = false

---@param vehicle number
---@return table
local function saveOriginalState(vehicle)
    local color1, color2 = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    return {
        color1 = color1,
        color2 = color2,
        pearlescentColor = pearl,
        wheelColor = wheel,
        paintType1 = GetVehicleModColor_1(vehicle),
        paintType2 = GetVehicleModColor_2(vehicle),
        livery = GetVehicleLivery(vehicle)
    }
end

---@param vehicle number
---@param props table
local function restoreState(vehicle, props)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleColours(vehicle, props.color1, props.color2)
    SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
    if props.livery >= 0 then
        SetVehicleLivery(vehicle, props.livery)
    end
end

---@param vehicle number
---@return table
local function getLiveries(vehicle)
    local liveries = {}
    local count = GetVehicleLiveryCount(vehicle)
    if count > 0 then
        for i = 0, count - 1 do
            liveries[#liveries + 1] = { index = i, name = GetLiveryName(vehicle, i) or ('Livery ' .. (i + 1)) }
        end
    end
    local modCount = GetNumVehicleMods(vehicle, 48)
    if modCount > 0 then
        for i = 0, modCount - 1 do
            liveries[#liveries + 1] = { index = 100 + i, name = GetModTextLabel(vehicle, 48, i) or ('Mod Livery ' .. (i + 1)) }
        end
    end
    return liveries
end

local function closeNUI()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    if activeVehicle and originalProps and DoesEntityExist(activeVehicle) then
        restoreState(activeVehicle, originalProps)
    end

    activeVehicle = nil
    originalProps = nil
end

---@param vehicle number
function Wrapping.Open(vehicle)
    if not Config.Wrapping.enabled then return end
    if not DoesEntityExist(vehicle) then return end
    if nuiOpen then return end

    activeVehicle = vehicle
    originalProps = saveOriginalState(vehicle)
    nuiOpen = true

    local liveries = getLiveries(vehicle)
    local catalog = lib.callback.await('mechanic:server:getWrapCatalog', false) or {}

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        mode = 'wrap',
        basePrice = Config.Wrapping.basePrice,
        materials = Config.Wrapping.materials,
        liveries = liveries,
        catalog = catalog
    })
end

RegisterNUICallback('wrapPreview', function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) then
        local colorIndex = tonumber(data.colorIndex) or -1
        if colorIndex >= 0 then
            if data.zone == 'primary' then
                local _, c2 = GetVehicleColours(activeVehicle)
                SetVehicleColours(activeVehicle, colorIndex, c2)
            else
                local c1 = GetVehicleColours(activeVehicle)
                SetVehicleColours(activeVehicle, c1, colorIndex)
            end
        end

        local matData = Config.Wrapping.materials[data.material]
        if matData then
            local paintType = matData.paintType
            SetVehicleModColor_1(activeVehicle, colorIndex >= 0 and colorIndex or 0, paintType)
            SetVehicleModColor_2(activeVehicle, colorIndex >= 0 and colorIndex or 0, paintType)
            if matData.pearlescent and colorIndex >= 0 then
                local _, wheel = GetVehicleExtraColours(activeVehicle)
                SetVehicleExtraColours(activeVehicle, colorIndex, wheel)
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('wrapLiveryPreview', function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) then
        local idx = tonumber(data.liveryIndex) or -1
        if idx >= 100 then
            SetVehicleMod(activeVehicle, 48, idx - 100, false)
        elseif idx >= 0 then
            SetVehicleLivery(activeVehicle, idx)
        end
    end
    cb('ok')
end)

RegisterNUICallback('wrapCatalogPreview', function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) then
        local catalog = lib.callback.await('mechanic:server:getWrapCatalog', false) or {}
        for _, entry in ipairs(catalog) do
            if entry.id == data.catalogId then
                SetVehicleColours(activeVehicle, entry.primary_color, entry.secondary_color)
                SetVehicleModColor_1(activeVehicle, entry.primary_color, entry.paint_type)
                SetVehicleModColor_2(activeVehicle, entry.secondary_color, entry.paint_type)
                if entry.pearlescent_color then
                    local _, wheel = GetVehicleExtraColours(activeVehicle)
                    SetVehicleExtraColours(activeVehicle, entry.pearlescent_color, wheel)
                end
                break
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('wrapConfirm', function(data, cb)
    if not activeVehicle or not DoesEntityExist(activeVehicle) then
        closeNUI()
        cb('ok')
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(activeVehicle)
    local success = false

    if data.catalogId and data.catalogId >= 0 then
        success = lib.callback.await('mechanic:server:applyWrapCatalog', false, netId, data.catalogId)
    else
        success = lib.callback.await('mechanic:server:applyWrap', false,
            netId,
            data.primaryColor or -1,
            data.secondaryColor or -1,
            data.material or 'gloss',
            data.liveryIndex or -1)
    end

    if success then
        lib.notify({ title = locale('wrap_applied'), type = 'success' })
        originalProps = nil
    else
        if originalProps then
            restoreState(activeVehicle, originalProps)
        end
    end

    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    activeVehicle = nil
    originalProps = nil
    cb('ok')
end)

RegisterNUICallback('wrapCancel', function(_, cb)
    closeNUI()
    lib.notify({ title = locale('wrap_cancelled'), type = 'info' })
    cb('ok')
end)

return Wrapping

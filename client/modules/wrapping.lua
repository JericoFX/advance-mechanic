local Wrapping = {}

---@type number|nil
local activeVehicle = nil
---@type table|nil
local originalProps = nil

local colorPalette = {
    { name = 'Black', index = 0, hex = '#0d1116' },
    { name = 'Graphite', index = 1, hex = '#1c1d21' },
    { name = 'Silver', index = 4, hex = '#999da0' },
    { name = 'White', index = 6, hex = '#f5f5f5' },
    { name = 'Red', index = 27, hex = '#c00e1a' },
    { name = 'Torino Red', index = 28, hex = '#da1918' },
    { name = 'Wine Red', index = 143, hex = '#5c0a0a' },
    { name = 'Dark Green', index = 49, hex = '#132428' },
    { name = 'Racing Green', index = 50, hex = '#122e2b' },
    { name = 'Bright Green', index = 53, hex = '#155c2d' },
    { name = 'Dark Blue', index = 141, hex = '#1f2852' },
    { name = 'Saxony Blue', index = 36, hex = '#1e3a5b' },
    { name = 'Ultra Blue', index = 70, hex = '#2054a6' },
    { name = 'Yellow', index = 88, hex = '#f5a623' },
    { name = 'Race Yellow', index = 89, hex = '#e0c215' },
    { name = 'Orange', index = 130, hex = '#e0782e' },
    { name = 'Purple', index = 71, hex = '#6b1f7b' },
    { name = 'Hot Pink', index = 135, hex = '#e63f7b' },
    { name = 'Cream', index = 107, hex = '#f5e8c8' },
    { name = 'Chocolate Brown', index = 96, hex = '#3e2710' },
    { name = 'Sand', index = 105, hex = '#c4b99e' },
}

---@param vehicle number
---@return table
local function saveOriginalState(vehicle)
    local c1, c2 = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    return {
        color1 = c1,
        color2 = c2,
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

---@param vehicle number
---@param zone string
---@param colorIndex number
---@param material string
local function applyWrapPreview(vehicle, zone, colorIndex, material)
    if not DoesEntityExist(vehicle) then return end

    if zone == 'primary' then
        local _, c2 = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, colorIndex, c2)
    else
        local c1 = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, c1, colorIndex)
    end

    local matData = Config.Wrapping.materials[material]
    if matData then
        SetVehicleModColor_1(vehicle, colorIndex, matData.paintType)
        SetVehicleModColor_2(vehicle, colorIndex, matData.paintType)
        if matData.pearlescent then
            local _, wheel = GetVehicleExtraColours(vehicle)
            SetVehicleExtraColours(vehicle, colorIndex, wheel)
        end
    end
end

---@param vehicle number
---@param zone string
---@param material string
---@param colorIndex number
local function confirmWrap(vehicle, zone, material, colorIndex)
    local price = math.floor(Config.Wrapping.basePrice * (Config.Wrapping.materials[material] and Config.Wrapping.materials[material].priceMultiplier or 1.0))

    local options = {
        {
            title = locale('wrap_zone_' .. zone) .. ' — ' .. locale('wrap_material_' .. material),
            icon = 'fas fa-eye',
            iconColor = '#3498db',
            disabled = true,
            metadata = {
                { label = locale('price'), value = '$' .. price }
            }
        },
        {
            title = locale('confirm_purchase'),
            icon = 'fas fa-check',
            iconColor = '#2ecc71',
            onSelect = function()
                local progress = lib.progressBar({
                    duration = 8000,
                    label = locale('applying_paint'),
                    useWhileDead = false,
                    canCancel = false,
                    disable = { move = true, car = true }
                })

                if progress then
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    local primaryColor = zone == 'primary' and colorIndex or -1
                    local secondaryColor = zone == 'secondary' and colorIndex or -1
                    local success = lib.callback.await('mechanic:server:applyWrap', false,
                        netId, primaryColor, secondaryColor, material, -1)

                    if success then
                        lib.notify({ title = locale('wrap_applied'), type = 'success' })
                        originalProps = nil
                    else
                        restoreState(vehicle, originalProps)
                    end
                end

                activeVehicle = nil
                originalProps = nil
            end
        },
        {
            title = locale('paint_cancelled'),
            icon = 'fas fa-times',
            iconColor = '#e74c3c',
            onSelect = function()
                restoreState(vehicle, originalProps)
                activeVehicle = nil
                originalProps = nil
            end
        }
    }

    lib.registerContext({
        id = 'wrap_confirm',
        title = locale('confirm_purchase'),
        menu = 'wrap_colors',
        options = options
    })

    lib.showContext('wrap_confirm')
end

---@param vehicle number
---@param zone string
---@param material string
local function showWrapColorMenu(vehicle, zone, material)
    local options = {}

    for _, color in ipairs(colorPalette) do
        options[#options + 1] = {
            title = color.name,
            icon = 'fas fa-square-full',
            iconColor = color.hex,
            onSelect = function()
                applyWrapPreview(vehicle, zone, color.index, material)
                confirmWrap(vehicle, zone, material, color.index)
            end
        }
    end

    lib.registerContext({
        id = 'wrap_colors',
        title = locale('primary_color'),
        menu = 'wrap_material_menu',
        options = options
    })

    lib.showContext('wrap_colors')
end

---@param vehicle number
---@param zone string
local function showMaterialMenu(vehicle, zone)
    local options = {}

    for matKey, matData in pairs(Config.Wrapping.materials) do
        local price = math.floor(Config.Wrapping.basePrice * matData.priceMultiplier)
        options[#options + 1] = {
            title = locale('wrap_material_' .. matKey),
            icon = 'fas fa-layer-group',
            metadata = { { label = locale('price'), value = '$' .. price } },
            onSelect = function()
                showWrapColorMenu(vehicle, zone, matKey)
            end
        }
    end

    lib.registerContext({
        id = 'wrap_material_menu',
        title = locale('wrap_material_gloss'),
        menu = 'wrapping_menu',
        options = options
    })

    lib.showContext('wrap_material_menu')
end

---@param vehicle number
local function showLiveryMenu(vehicle)
    local liveries = getLiveries(vehicle)

    if #liveries == 0 then
        lib.notify({ title = locale('wrap_no_liveries'), type = 'info' })
        return
    end

    local options = {}
    for _, liv in ipairs(liveries) do
        options[#options + 1] = {
            title = liv.name,
            icon = 'fas fa-image',
            onSelect = function()
                if liv.index >= 100 then
                    SetVehicleMod(vehicle, 48, liv.index - 100, false)
                else
                    SetVehicleLivery(vehicle, liv.index)
                end

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local success = lib.callback.await('mechanic:server:applyWrap', false,
                    netId, -1, -1, 'gloss', liv.index)

                if success then
                    lib.notify({ title = locale('wrap_applied'), type = 'success' })
                    originalProps = nil
                else
                    restoreState(vehicle, originalProps)
                end

                activeVehicle = nil
                originalProps = nil
            end
        }
    end

    lib.registerContext({
        id = 'wrap_liveries',
        title = 'Liveries',
        menu = 'wrapping_menu',
        options = options
    })

    lib.showContext('wrap_liveries')
end

---@param vehicle number
local function showCatalogMenu(vehicle)
    local catalog = lib.callback.await('mechanic:server:getWrapCatalog', false) or {}

    if #catalog == 0 then
        lib.notify({ title = locale('wrap_no_liveries'), type = 'info' })
        return
    end

    local options = {}
    for _, entry in ipairs(catalog) do
        options[#options + 1] = {
            title = entry.name,
            icon = 'fas fa-palette',
            metadata = { { label = locale('price'), value = '$' .. entry.price } },
            onSelect = function()
                SetVehicleColours(vehicle, entry.primary_color, entry.secondary_color)
                SetVehicleModColor_1(vehicle, entry.primary_color, entry.paint_type)
                SetVehicleModColor_2(vehicle, entry.secondary_color, entry.paint_type)
                if entry.pearlescent_color then
                    local _, wheel = GetVehicleExtraColours(vehicle)
                    SetVehicleExtraColours(vehicle, entry.pearlescent_color, wheel)
                end

                local confirm = lib.alertDialog({
                    header = entry.name,
                    content = locale('purchase_confirmation', 1, entry.name, entry.price),
                    centered = true,
                    cancel = true
                })

                if confirm == 'confirm' then
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    local success = lib.callback.await('mechanic:server:applyWrapCatalog', false, netId, entry.id)

                    if success then
                        lib.notify({ title = locale('wrap_applied'), type = 'success' })
                        originalProps = nil
                    else
                        restoreState(vehicle, originalProps)
                    end
                else
                    restoreState(vehicle, originalProps)
                end

                activeVehicle = nil
                originalProps = nil
            end
        }
    end

    lib.registerContext({
        id = 'wrap_catalog',
        title = 'Wrap Catalog',
        menu = 'wrapping_menu',
        options = options
    })

    lib.showContext('wrap_catalog')
end

function Wrapping.Open(vehicle)
    if not Config.Wrapping.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    activeVehicle = vehicle
    originalProps = saveOriginalState(vehicle)

    local liveries = getLiveries(vehicle)

    local options = {
        {
            title = locale('wrap_zone_primary'),
            description = locale('primary_color'),
            icon = 'fas fa-car',
            iconColor = '#3498db',
            onSelect = function() showMaterialMenu(vehicle, 'primary') end
        },
        {
            title = locale('wrap_zone_secondary'),
            description = locale('secondary_color'),
            icon = 'fas fa-car-side',
            iconColor = '#e74c3c',
            onSelect = function() showMaterialMenu(vehicle, 'secondary') end
        },
        {
            title = 'Liveries',
            description = #liveries .. ' available',
            icon = 'fas fa-images',
            iconColor = '#f39c12',
            disabled = #liveries == 0,
            onSelect = function() showLiveryMenu(vehicle) end
        },
        {
            title = 'Wrap Catalog',
            description = locale('purchase_item'),
            icon = 'fas fa-book-open',
            iconColor = '#9b59b6',
            onSelect = function() showCatalogMenu(vehicle) end
        }
    }

    lib.registerContext({
        id = 'wrapping_menu',
        title = locale('vehicle_wrapping'),
        options = options,
        onClose = function()
            if activeVehicle and originalProps and DoesEntityExist(activeVehicle) then
                restoreState(activeVehicle, originalProps)
            end
            activeVehicle = nil
            originalProps = nil
        end
    })

    lib.showContext('wrapping_menu')
end

return Wrapping

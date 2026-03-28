local PaintBooth = {}

---@type number|nil
local activeVehicle = nil
---@type table|nil
local originalProps = nil

local colorPalette = {
    { name = 'Black', index = 0, hex = '#0d1116' },
    { name = 'Graphite', index = 1, hex = '#1c1d21' },
    { name = 'Dark Silver', index = 3, hex = '#5a5e66' },
    { name = 'Silver', index = 4, hex = '#999da0' },
    { name = 'Blue Silver', index = 5, hex = '#c2c4c6' },
    { name = 'White', index = 6, hex = '#f5f5f5' },
    { name = 'Frost White', index = 112, hex = '#ffffff' },
    { name = 'Red', index = 27, hex = '#c00e1a' },
    { name = 'Torino Red', index = 28, hex = '#da1918' },
    { name = 'Formula Red', index = 29, hex = '#b91d1d' },
    { name = 'Lava Red', index = 150, hex = '#d44240' },
    { name = 'Grace Red', index = 31, hex = '#742b2b' },
    { name = 'Garnet Red', index = 32, hex = '#781e1e' },
    { name = 'Sunset Red', index = 33, hex = '#521b1b' },
    { name = 'Cabernet Red', index = 34, hex = '#371a1a' },
    { name = 'Wine Red', index = 143, hex = '#5c0a0a' },
    { name = 'Dark Green', index = 49, hex = '#132428' },
    { name = 'Racing Green', index = 50, hex = '#122e2b' },
    { name = 'Sea Green', index = 51, hex = '#12383c' },
    { name = 'Olive Green', index = 52, hex = '#31423f' },
    { name = 'Bright Green', index = 53, hex = '#155c2d' },
    { name = 'Gasoline Green', index = 54, hex = '#1b4a37' },
    { name = 'Lime Green', index = 92, hex = '#418c54' },
    { name = 'Dark Blue', index = 141, hex = '#1f2852' },
    { name = 'Midnight Blue', index = 82, hex = '#253355' },
    { name = 'Saxony Blue', index = 36, hex = '#1e3a5b' },
    { name = 'Mariner Blue', index = 37, hex = '#1e4f8f' },
    { name = 'Harbor Blue', index = 38, hex = '#113f6b' },
    { name = 'Racing Blue', index = 64, hex = '#3b56a0' },
    { name = 'Ultra Blue', index = 70, hex = '#2054a6' },
    { name = 'Light Blue', index = 139, hex = '#5c8ed3' },
    { name = 'Yellow', index = 88, hex = '#f5a623' },
    { name = 'Race Yellow', index = 89, hex = '#e0c215' },
    { name = 'Bronze', index = 90, hex = '#a48848' },
    { name = 'Dew Yellow', index = 91, hex = '#e6c34d' },
    { name = 'Orange', index = 38, hex = '#d66b15' },
    { name = 'Sunrise Orange', index = 130, hex = '#e0782e' },
    { name = 'Gold', index = 37, hex = '#c4a24d' },
    { name = 'Purple', index = 71, hex = '#6b1f7b' },
    { name = 'Spinnaker Purple', index = 72, hex = '#38184c' },
    { name = 'Midnight Purple', index = 142, hex = '#292140' },
    { name = 'Hot Pink', index = 135, hex = '#e63f7b' },
    { name = 'Pfister Pink', index = 136, hex = '#d14d8f' },
    { name = 'Salmon Pink', index = 137, hex = '#c87e8e' },
    { name = 'Cream', index = 107, hex = '#f5e8c8' },
    { name = 'Ice White', index = 111, hex = '#e3ddd4' },
    { name = 'Chocolate Brown', index = 96, hex = '#3e2710' },
    { name = 'Bison Brown', index = 97, hex = '#473222' },
    { name = 'Creek Brown', index = 100, hex = '#5a3e26' },
    { name = 'Sand', index = 105, hex = '#c4b99e' },
    { name = 'Straw Beige', index = 108, hex = '#b0a07a' },
}

---@param vehicle number
---@return table
local function saveOriginalColors(vehicle)
    local c1, c2 = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    return {
        color1 = c1,
        color2 = c2,
        pearlescentColor = pearl,
        wheelColor = wheel,
        paintType1 = GetVehicleModColor_1(vehicle),
        paintType2 = GetVehicleModColor_2(vehicle)
    }
end

---@param vehicle number
---@param props table
local function restoreColors(vehicle, props)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleColours(vehicle, props.color1, props.color2)
    SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
end

---@param vehicle number
---@param paintType string
---@param colorIndex number
---@param pearlIndex number|nil
local function applyPreview(vehicle, paintType, colorIndex, pearlIndex)
    if not DoesEntityExist(vehicle) then return end

    if paintType == 'chrome' then
        SetVehicleColours(vehicle, 120, 120)
    elseif paintType == 'pearlescent' then
        SetVehicleColours(vehicle, colorIndex, colorIndex)
        if pearlIndex and pearlIndex >= 0 then
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

---@param vehicle number
---@param paintType string
---@param colorIndex number
---@param pearlIndex number|nil
local function confirmPaint(vehicle, paintType, colorIndex, pearlIndex)
    local price = math.floor(Config.PaintBooth.basePrice * (Config.PaintBooth.priceMultipliers[paintType] or 1.0))

    local options = {
        {
            title = locale('paint_type_' .. paintType),
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
                    local success = lib.callback.await('mechanic:server:applyPaint', false,
                        netId, paintType, colorIndex, pearlIndex or -1)

                    if success then
                        lib.notify({ title = locale('paint_applied'), type = 'success' })
                        originalProps = nil
                    else
                        restoreColors(vehicle, originalProps)
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
                restoreColors(vehicle, originalProps)
                activeVehicle = nil
                originalProps = nil
            end
        }
    }

    lib.registerContext({
        id = 'paint_confirm',
        title = locale('confirm_purchase'),
        menu = 'paint_colors',
        options = options
    })

    lib.showContext('paint_confirm')
end

---@param vehicle number
---@param paintType string
---@param parentMenu string
local function showColorMenu(vehicle, paintType, parentMenu)
    local options = {}

    for _, color in ipairs(colorPalette) do
        options[#options + 1] = {
            title = color.name,
            icon = 'fas fa-square-full',
            iconColor = color.hex,
            onSelect = function()
                applyPreview(vehicle, paintType, color.index)
                if paintType == 'pearlescent' then
                    showPearlMenu(vehicle, color.index)
                else
                    confirmPaint(vehicle, paintType, color.index)
                end
            end
        }
    end

    lib.registerContext({
        id = 'paint_colors',
        title = locale('primary_color'),
        menu = parentMenu,
        options = options
    })

    lib.showContext('paint_colors')
end

---@param vehicle number
---@param mainColor number
function showPearlMenu(vehicle, mainColor)
    local options = {}

    for _, color in ipairs(colorPalette) do
        options[#options + 1] = {
            title = color.name,
            icon = 'fas fa-square-full',
            iconColor = color.hex,
            onSelect = function()
                applyPreview(vehicle, 'pearlescent', mainColor, color.index)
                confirmPaint(vehicle, 'pearlescent', mainColor, color.index)
            end
        }
    end

    lib.registerContext({
        id = 'paint_pearl_colors',
        title = locale('pearlescent'),
        menu = 'paint_colors',
        options = options
    })

    lib.showContext('paint_pearl_colors')
end

function PaintBooth.Open(vehicle)
    if not Config.PaintBooth.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    activeVehicle = vehicle
    originalProps = saveOriginalColors(vehicle)

    local mult = Config.PaintBooth.priceMultipliers
    local base = Config.PaintBooth.basePrice

    local options = {
        {
            title = locale('paint_type_standard'),
            icon = 'fas fa-spray-can',
            iconColor = '#3498db',
            metadata = { { label = locale('price'), value = '$' .. math.floor(base * mult.standard) } },
            onSelect = function() showColorMenu(vehicle, 'standard', 'paint_booth_menu') end
        },
        {
            title = locale('paint_type_metallic'),
            icon = 'fas fa-spray-can',
            iconColor = '#c0c0c0',
            metadata = { { label = locale('price'), value = '$' .. math.floor(base * mult.metallic) } },
            onSelect = function() showColorMenu(vehicle, 'metallic', 'paint_booth_menu') end
        },
        {
            title = locale('paint_type_matte'),
            icon = 'fas fa-spray-can',
            iconColor = '#666666',
            metadata = { { label = locale('price'), value = '$' .. math.floor(base * mult.matte) } },
            onSelect = function() showColorMenu(vehicle, 'matte', 'paint_booth_menu') end
        },
        {
            title = locale('paint_type_chrome'),
            icon = 'fas fa-spray-can',
            iconColor = '#e8e8e8',
            metadata = { { label = locale('price'), value = '$' .. math.floor(base * mult.chrome) } },
            onSelect = function()
                applyPreview(vehicle, 'chrome', 120)
                confirmPaint(vehicle, 'chrome', 120)
            end
        },
        {
            title = locale('paint_type_pearlescent'),
            icon = 'fas fa-spray-can',
            iconColor = '#9b59b6',
            metadata = { { label = locale('price'), value = '$' .. math.floor(base * mult.pearlescent) } },
            onSelect = function() showColorMenu(vehicle, 'pearlescent', 'paint_booth_menu') end
        }
    }

    lib.registerContext({
        id = 'paint_booth_menu',
        title = locale('paint_booth'),
        options = options,
        onClose = function()
            if activeVehicle and originalProps and DoesEntityExist(activeVehicle) then
                restoreColors(activeVehicle, originalProps)
            end
            activeVehicle = nil
            originalProps = nil
        end
    })

    lib.showContext('paint_booth_menu')
end

return PaintBooth

local SuspensionSetup = {}

---@type table
local defaultValues = {
    frontHeight = 0.0,
    rearHeight = 0.0,
    stiffness = 50,
    frontCamber = 0.0,
    rearCamber = 0.0,
    frontToe = 0.0,
    rearToe = 0.0
}

---@param vehicle number
---@param data table
local function applyVisuals(vehicle, data)
    if not DoesEntityExist(vehicle) then return end

    local camberToOffset = 0.003
    SetVehicleWheelXOffset(vehicle, 0, -(data.frontCamber or 0) * camberToOffset)
    SetVehicleWheelXOffset(vehicle, 1, (data.frontCamber or 0) * camberToOffset)
    SetVehicleWheelXOffset(vehicle, 2, -(data.rearCamber or 0) * camberToOffset)
    SetVehicleWheelXOffset(vehicle, 3, (data.rearCamber or 0) * camberToOffset)

    local heightValue = ((data.frontHeight or 0) + (data.rearHeight or 0)) / 2
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionRaise', heightValue)
end

---@param vehicle number
---@param data table
local function applyHandling(vehicle, data)
    if not DoesEntityExist(vehicle) then return end

    local stiffness = (data.stiffness or 50) / 100.0
    local suspForce = 1.0 + (stiffness * 3.0)
    local compDamp = 1.0 + (stiffness * 2.0)
    local reboundDamp = 1.5 + (stiffness * 2.5)

    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce', suspForce)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionCompDamp', compDamp)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionReboundDamp', reboundDamp)

    local maxCamber = math.max(math.abs(data.frontCamber or 0), math.abs(data.rearCamber or 0))
    if maxCamber > 8 then
        local gripLoss = ((maxCamber - 8) / 7.0) * 0.2
        local currentGrip = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax')
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', currentGrip * (1.0 - gripLoss))
    end

    local avgToe = ((data.frontToe or 0) + (data.rearToe or 0)) / 2
    if math.abs(avgToe) > 0.5 then
        local currentLock = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock')
        local toeFactor = 1.0 + (avgToe * 0.02)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', currentLock * toeFactor)
    end
end

---@param vehicle number
---@param data table
function SuspensionSetup.Apply(vehicle, data)
    applyVisuals(vehicle, data)
    applyHandling(vehicle, data)
end

---@param vehicle number
function SuspensionSetup.Open(vehicle)
    if not Config.Suspension.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    if Config.Suspension.requireLift then
        local vehicleState = Entity(vehicle).state
        if not vehicleState or not vehicleState.onLift then
            lib.notify({ title = locale('suspension_requires_lift'), type = 'error' })
            return
        end
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local currentData = lib.callback.await('mechanic:server:getSuspensionData', false, plate)

    local values = {}
    for param, default in pairs(defaultValues) do
        values[param] = currentData and currentData[param:gsub('(%u)', function(c) return '_' .. c:lower() end)] or default
    end

    if currentData then
        values.frontHeight = currentData.front_height or 0
        values.rearHeight = currentData.rear_height or 0
        values.stiffness = currentData.stiffness or 50
        values.frontCamber = currentData.front_camber or 0
        values.rearCamber = currentData.rear_camber or 0
        values.frontToe = currentData.front_toe or 0
        values.rearToe = currentData.rear_toe or 0
    end

    local ranges = Config.Suspension.ranges

    local options = {
        {
            title = locale('suspension_setup'),
            icon = 'fas fa-sliders-h',
            onSelect = function()
                local input = lib.inputDialog(locale('suspension_setup'), {
                    { type = 'slider', label = locale('suspension_front_height'), default = math.floor((values.frontHeight + 0.1) * 500), min = 0, max = 100, step = 1 },
                    { type = 'slider', label = locale('suspension_rear_height'), default = math.floor((values.rearHeight + 0.1) * 500), min = 0, max = 100, step = 1 },
                    { type = 'slider', label = locale('suspension_stiffness'), default = values.stiffness, min = ranges.stiffness.min, max = ranges.stiffness.max, step = 1 },
                    { type = 'slider', label = locale('suspension_front_camber'), default = math.floor(values.frontCamber + 15), min = 0, max = 30, step = 1 },
                    { type = 'slider', label = locale('suspension_rear_camber'), default = math.floor(values.rearCamber + 15), min = 0, max = 30, step = 1 },
                    { type = 'slider', label = locale('suspension_front_toe'), default = math.floor(values.frontToe + 5), min = 0, max = 10, step = 1 },
                    { type = 'slider', label = locale('suspension_rear_toe'), default = math.floor(values.rearToe + 5), min = 0, max = 10, step = 1 }
                })

                if not input then
                    lib.notify({ title = locale('suspension_cancelled'), type = 'info' })
                    return
                end

                local newData = {
                    frontHeight = (input[1] / 500) - 0.1,
                    rearHeight = (input[2] / 500) - 0.1,
                    stiffness = input[3],
                    frontCamber = input[4] - 15.0,
                    rearCamber = input[5] - 15.0,
                    frontToe = input[6] - 5.0,
                    rearToe = input[7] - 5.0
                }

                SuspensionSetup.Apply(vehicle, newData)

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local success = lib.callback.await('mechanic:server:applySuspension', false, netId, newData)

                if success then
                    lib.notify({ title = locale('suspension_applied'), type = 'success' })
                else
                    SuspensionSetup.Apply(vehicle, values)
                end
            end
        },
        {
            title = locale('suspension_load_preset'),
            icon = 'fas fa-download',
            onSelect = function()
                SuspensionSetup.LoadPresetMenu(vehicle)
            end
        },
        {
            title = locale('suspension_save_preset'),
            icon = 'fas fa-save',
            onSelect = function()
                SuspensionSetup.SavePresetMenu(vehicle, plate)
            end
        }
    }

    lib.registerContext({
        id = 'suspension_setup_menu',
        title = locale('suspension_setup'),
        options = options
    })

    lib.showContext('suspension_setup_menu')
end

function SuspensionSetup.LoadPresetMenu(vehicle)
    local presets = lib.callback.await('mechanic:server:getSuspensionPresets', false, 1)
    if not presets or #presets == 0 then
        lib.notify({ title = locale('suspension_no_presets'), type = 'info' })
        return
    end

    local options = {}
    for _, preset in ipairs(presets) do
        options[#options + 1] = {
            title = preset.name,
            icon = 'fas fa-cog',
            onSelect = function()
                SuspensionSetup.Apply(vehicle, preset.data)

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local success = lib.callback.await('mechanic:server:applySuspension', false, netId, preset.data)

                if success then
                    lib.notify({ title = locale('suspension_preset_loaded'), type = 'success' })
                end
            end
        }
    end

    lib.registerContext({
        id = 'suspension_presets_menu',
        title = locale('suspension_load_preset'),
        menu = 'suspension_setup_menu',
        options = options
    })

    lib.showContext('suspension_presets_menu')
end

function SuspensionSetup.SavePresetMenu(vehicle, plate)
    local input = lib.inputDialog(locale('suspension_save_preset'), {
        { type = 'input', label = locale('suspension_preset_name'), required = true, max = 50 }
    })

    if not input or not input[1] then return end

    local currentData = lib.callback.await('mechanic:server:getSuspensionData', false, plate)
    if not currentData then
        lib.notify({ title = locale('suspension_cancelled'), type = 'error' })
        return
    end

    local data = {
        frontHeight = currentData.front_height or 0,
        rearHeight = currentData.rear_height or 0,
        stiffness = currentData.stiffness or 50,
        frontCamber = currentData.front_camber or 0,
        rearCamber = currentData.rear_camber or 0,
        frontToe = currentData.front_toe or 0,
        rearToe = currentData.rear_toe or 0
    }

    local success = lib.callback.await('mechanic:server:saveSuspensionPreset', false, 1, input[1], data)

    if success then
        lib.notify({ title = locale('suspension_preset_saved'), type = 'success' })
    end
end

AddStateBagChangeHandler('suspensionData', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SuspensionSetup.Apply(entity, value)
    end
end)

return SuspensionSetup

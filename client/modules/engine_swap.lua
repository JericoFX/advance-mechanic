local EngineSwap = {}
local VisualEffects = require 'client.modules.visual_effects'

local simulationThread = nil
local simulationActive = false
local handlingCache = {}
local monitorStarted = false

---@param vehicle number
---@return table
local function getVehicleDefaults(vehicle)
    local class = GetVehicleClass(vehicle)
    return Config.VehicleClassDefaults[class] or Config.VehicleClassDefaults[0]
end

---@param curve table
---@param rpmNormalized number
---@return number
local function interpolateTorqueCurve(curve, rpmNormalized)
    if not curve or #curve == 0 then return 1.0 end

    local rpmActual = rpmNormalized * (curve[#curve].rpm or 7000)

    if rpmActual <= curve[1].rpm then return curve[1].percent / 100 end
    if rpmActual >= curve[#curve].rpm then return curve[#curve].percent / 100 end

    for i = 1, #curve - 1 do
        if rpmActual >= curve[i].rpm and rpmActual <= curve[i + 1].rpm then
            local t = (rpmActual - curve[i].rpm) / (curve[i + 1].rpm - curve[i].rpm)
            local percent = curve[i].percent + t * (curve[i + 1].percent - curve[i].percent)
            return percent / 100
        end
    end

    return 1.0
end

---@param vehicle number
---@param key string
---@return number
local function getCachedHandling(vehicle, key)
    if not handlingCache[vehicle] then
        handlingCache[vehicle] = {}
    end
    if handlingCache[vehicle][key] == nil then
        handlingCache[vehicle][key] = GetVehicleHandlingFloat(vehicle, 'CHandlingData', key)
    end
    return handlingCache[vehicle][key]
end

---@param vehicle number
---@param engineConfig table
---@param defaultEngine table
local function applyStaticHandling(vehicle, engineConfig, defaultEngine)
    if not DoesEntityExist(vehicle) then return end

    local hpRatio = engineConfig.hp / defaultEngine.hp
    local weightRatio = engineConfig.weight / defaultEngine.weight
    local rpmRatio = engineConfig.rpmMax / defaultEngine.rpmMax

    local baseDriveInertia = getCachedHandling(vehicle, 'fDriveInertia')
    local baseMaxVel = getCachedHandling(vehicle, 'fInitialDriveMaxFlatVel')
    local baseClutchUp = getCachedHandling(vehicle, 'fClutchChangeRateScaleUpShift')
    local baseClutchDown = getCachedHandling(vehicle, 'fClutchChangeRateScaleDownShift')

    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveInertia', baseDriveInertia * weightRatio)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', baseMaxVel * rpmRatio)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift', baseClutchUp * (1.0 / weightRatio))
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift', baseClutchDown * (1.0 / weightRatio))
end

---@param vehicle number
local function restoreHandling(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local cached = handlingCache[vehicle]
    if not cached then return end

    for key, value in pairs(cached) do
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, value)
    end

    handlingCache[vehicle] = nil
end

---@param vehicle number
local function startSimulation(vehicle)
    if simulationThread then return end

    local vehicleState = Entity(vehicle).state
    local engineData = vehicleState.engineData
    if not engineData then return end

    local engineConfig = Config.Engines[engineData.engineId]
    if not engineConfig then return end

    local defaults = getVehicleDefaults(vehicle)
    local defaultEngine = Config.Engines[defaults.engine]
    if not defaultEngine then return end

    applyStaticHandling(vehicle, engineConfig, defaultEngine)

    local baseDriveForce = getCachedHandling(vehicle, 'fInitialDriveForce')
    local hpRatio = engineConfig.hp / defaultEngine.hp

    simulationActive = true
    simulationThread = true
    local temperature = engineData.temperature or 20.0
    local wear = engineData.wear or 0.0
    local totalKm = engineData.totalKm or 0.0
    local lastCoords = GetEntityCoords(vehicle)
    local lastHealthCheck = GetVehicleEngineHealth(vehicle)
    local tickCounter = 0
    local thresholds = Config.EngineSwap.temperatureThresholds
    local wearThresholds = Config.EngineSwap.wearThresholds

    CreateThread(function()
        while simulationActive and cache.vehicle == vehicle and cache.seat == -1 do
            tickCounter = tickCounter + 1

            if DoesEntityExist(vehicle) then
                local rpmNormalized = GetVehicleCurrentRpm(vehicle)
                local torqueMultiplier = interpolateTorqueCurve(engineConfig.torqueCurve, rpmNormalized)

                local wearMultiplier = 1.0
                if wear > wearThresholds.heavy then
                    wearMultiplier = 0.70
                elseif wear > wearThresholds.moderate then
                    wearMultiplier = 0.85
                elseif wear > wearThresholds.light then
                    wearMultiplier = 0.95
                end

                local tempMultiplier = 1.0
                if temperature > thresholds.critical then
                    tempMultiplier = 0.70
                elseif temperature > thresholds.warning then
                    tempMultiplier = 0.90
                end

                local finalForce = baseDriveForce * hpRatio * torqueMultiplier * wearMultiplier * tempMultiplier
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', finalForce)

                if wear > wearThresholds.heavy and wear <= wearThresholds.critical then
                    if math.random() < Config.EngineSwap.misfireChance then
                        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', 0.0)
                        lib.notify({ title = locale('engine_misfire'), type = 'warning' })
                        Wait(200)
                        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', finalForce)
                    end
                elseif wear >= wearThresholds.critical then
                    if math.random() < Config.EngineSwap.breakdownChance then
                        SetVehicleEngineOn(vehicle, false, true, true)
                        lib.notify({ title = locale('engine_breakdown'), type = 'error', duration = 10000 })
                        local plate = GetVehicleNumberPlateText(vehicle)
                        if plate and plate ~= '' then
                            TriggerServerEvent('mechanic:server:syncEngineData', plate, wear, temperature, totalKm)
                        end
                        simulationActive = false
                        break
                    end
                end

                if tickCounter % 10 == 0 then
                    local throttle = GetControlNormal(0, 71)
                    local rpmPercent = rpmNormalized * engineConfig.rpmMax / engineConfig.rpmRedline

                    local state = Entity(vehicle).state
                    local coolantLevel = state.coolantLevel or 100
                    local coolantFactor = math.max(0.2, coolantLevel / 100)

                    local heatGain = engineConfig.heatRate * (rpmPercent * throttle) * 0.5
                    local cooling = engineConfig.coolingEfficiency * coolantFactor * 0.3
                    temperature = math.max(20, math.min(120, temperature + heatGain - cooling))

                    if temperature > thresholds.critical then
                        wear = math.min(100, wear + 0.1)
                        if temperature > 115 then
                            SetVehicleEngineOn(vehicle, false, true, true)
                            lib.notify({ title = locale('engine_overheat_warning'), type = 'error', duration = 10000 })
                            local plate = GetVehicleNumberPlateText(vehicle)
                            if plate and plate ~= '' then
                                TriggerServerEvent('mechanic:server:syncEngineData', plate, wear, temperature, totalKm)
                            end
                            simulationActive = false
                            break
                        end
                    end

                    state:set('engineData', {
                        engineId = engineData.engineId,
                        wear = wear,
                        temperature = temperature,
                        totalKm = totalKm
                    }, true)
                end

                if tickCounter % 50 == 0 then
                    local currentCoords = GetEntityCoords(vehicle)
                    local distance = #(currentCoords - lastCoords) / 1000
                    totalKm = totalKm + distance
                    lastCoords = currentCoords

                    local rpmPercent = rpmNormalized * engineConfig.rpmMax / engineConfig.rpmRedline
                    local wearDelta = engineConfig.wearRate * 0.01

                    if rpmPercent > 1.0 then
                        wearDelta = wearDelta * 3.0
                    end

                    local currentHealth = GetVehicleEngineHealth(vehicle)
                    if currentHealth < lastHealthCheck - 50 then
                        wearDelta = wearDelta + 0.5
                    end
                    lastHealthCheck = currentHealth

                    local state = Entity(vehicle).state
                    local oilLevel = state.oilLevel or 100
                    if oilLevel < 30 then
                        wearDelta = wearDelta * 1.5
                    end

                    wear = math.min(100, wear + wearDelta)
                end

                if tickCounter % 300 == 0 then
                    local plate = GetVehicleNumberPlateText(vehicle)
                    TriggerServerEvent('mechanic:server:syncEngineData', plate, wear, temperature, totalKm)
                    tickCounter = 0
                end
            end

            Wait(100)
        end

        simulationThread = nil
    end)
end

local function stopSimulation()
    if not simulationActive then return end
    simulationActive = false

    local vehicle = cache.vehicle
    if vehicle and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        local state = Entity(vehicle).state
        local engineData = state.engineData
        if engineData then
            TriggerServerEvent('mechanic:server:syncEngineData', plate, engineData.wear or 0, engineData.temperature or 20, engineData.totalKm or 0)
        end
    end
end

function EngineSwap.Monitor()
    if monitorStarted then return end
    monitorStarted = true

    lib.onCache('vehicle', function(vehicle)
        if vehicle and cache.seat == -1 then
            local state = Entity(vehicle).state
            if state.engineData then
                startSimulation(vehicle)
            else
                lib.callback.await('mechanic:server:loadEngineStateBag', false, VehToNet(vehicle))
                state = Entity(vehicle).state
                if state.engineData then
                    startSimulation(vehicle)
                end
            end
        else
            stopSimulation()
        end
    end)

    lib.onCache('seat', function(seat)
        if seat == -1 and cache.vehicle then
            local state = Entity(cache.vehicle).state
            if state.engineData then
                startSimulation(cache.vehicle)
            end
        else
            stopSimulation()
        end
    end)
end

function EngineSwap.Open(vehicle)
    if not Config.EngineSwap.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    if Config.EngineSwap.requireLift then
        local vehicleState = Entity(vehicle).state
        if not vehicleState or not vehicleState.onLift then
            lib.notify({ title = locale('engine_requires_lift'), type = 'error' })
            return
        end
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local engineData = lib.callback.await('mechanic:server:getEngineData', false, plate)

    local defaults = getVehicleDefaults(vehicle)
    local defaultEngine = Config.Engines[defaults.engine]

    local currentEngineId = engineData and engineData.engine_id or defaults.engine
    local currentEngine = Config.Engines[currentEngineId]
    local hasCustom = engineData ~= nil

    local currentName = currentEngine and currentEngine.name or locale('engine_stock')
    local currentHp = currentEngine and currentEngine.hp or 0
    local currentTorque = currentEngine and currentEngine.torque or 0

    local engineCount = 0
    for _ in pairs(Config.Engines) do engineCount = engineCount + 1 end

    local options = {
        {
            title = currentName,
            icon = 'fas fa-info-circle',
            iconColor = '#3498db',
            disabled = true,
            metadata = {
                { label = locale('engine_hp'), value = currentHp .. ' HP' },
                { label = locale('engine_torque'), value = currentTorque .. ' Nm' },
                { label = locale('engine_weight'), value = (currentEngine and currentEngine.weight or 0) .. ' kg' },
                { label = locale('engine_wear'), value = hasCustom and string.format('%.1f%%', engineData.wear) or 'N/A' },
                { label = locale('engine_temperature'), value = hasCustom and string.format('%.0f°C', engineData.temperature) or 'N/A' },
                { label = locale('engine_total_km'), value = hasCustom and string.format('%.1f km', engineData.total_km) or 'N/A' }
            }
        },
        {
            title = locale('browse_engines'),
            description = locale('engines_available', engineCount),
            icon = 'fas fa-list',
            iconColor = '#f39c12',
            arrow = true,
            onSelect = function()
                EngineSwap.CatalogMenu(vehicle, currentEngineId, defaults)
            end
        },
        {
            title = locale('remove_engine'),
            description = locale('restore_stock'),
            icon = 'fas fa-undo',
            iconColor = '#e74c3c',
            disabled = not hasCustom,
            onSelect = function()
                EngineSwap.RemoveEngine(vehicle)
            end
        }
    }

    lib.registerContext({
        id = 'engine_swap_menu',
        title = locale('engine_swap'),
        options = options
    })

    lib.showContext('engine_swap_menu')
end

function EngineSwap.CatalogMenu(vehicle, currentEngineId, defaults)
    local netId = VehToNet(vehicle)
    local options = {}

    for engineId, engineConfig in pairs(Config.Engines) do
        if engineId ~= currentEngineId then
            local compat = lib.callback.await('mechanic:server:getEngineCompatibility', false, netId, engineId)

            local isCompatible = compat and compat.drivetrainCompatible
            local hasParts = compat and compat.hasParts
            local isDisabled = not isCompatible or not hasParts

            local currentEngine = Config.Engines[currentEngineId]
            local hpDiff = engineConfig.hp - (currentEngine and currentEngine.hp or 0)
            local torqueDiff = engineConfig.torque - (currentEngine and currentEngine.torque or 0)
            local hpSign = hpDiff >= 0 and '+' or ''
            local torqueSign = torqueDiff >= 0 and '+' or ''

            local statusDesc = isDisabled and (not isCompatible and locale('engine_incompatible') or locale('engine_missing_parts')) or nil

            options[#options + 1] = {
                title = engineConfig.name .. ' — $' .. engineConfig.price,
                description = statusDesc,
                icon = 'fas fa-cog',
                iconColor = isCompatible and '#2ecc71' or '#e74c3c',
                disabled = isDisabled,
                metadata = {
                    { label = locale('engine_hp'), value = locale('engine_hp_change', engineConfig.hp, hpSign .. hpDiff) },
                    { label = locale('engine_torque'), value = locale('engine_torque_change', engineConfig.torque, torqueSign .. torqueDiff) },
                    { label = locale('engine_weight'), value = locale('engine_weight_kg', engineConfig.weight) },
                    { label = locale('engine_rpm_range'), value = locale('engine_rpm_format', engineConfig.rpmMax, engineConfig.rpmRedline) },
                    { label = locale('engine_drivetrain'), value = table.concat(engineConfig.drivetrainCompat, ', ') },
                    { label = locale('engine_install_time'), value = locale('engine_time_format', math.floor(engineConfig.installTime / 60)) }
                },
                onSelect = function()
                    EngineSwap.ConfirmMenu(vehicle, engineId, engineConfig, currentEngineId)
                end
            }
        end
    end

    lib.registerContext({
        id = 'engine_swap_catalog',
        title = locale('browse_engines'),
        menu = 'engine_swap_menu',
        options = options
    })

    lib.showContext('engine_swap_catalog')
end

function EngineSwap.ConfirmMenu(vehicle, engineId, engineConfig, currentEngineId)
    local currentEngine = Config.Engines[currentEngineId]

    local options = {
        {
            title = locale('engine_comparison'),
            icon = 'fas fa-exchange-alt',
            iconColor = '#9b59b6',
            disabled = true,
            metadata = {
                { label = locale('engine_hp'), value = locale('engine_current_vs_new', (currentEngine and currentEngine.hp or '?') .. ' HP', engineConfig.hp .. ' HP') },
                { label = locale('engine_torque'), value = locale('engine_current_vs_new', (currentEngine and currentEngine.torque or '?') .. ' Nm', engineConfig.torque .. ' Nm') },
                { label = locale('engine_price'), value = '$' .. engineConfig.price }
            }
        },
        {
            title = locale('confirm_install', engineConfig.name),
            icon = 'fas fa-check',
            iconColor = '#2ecc71',
            onSelect = function()
                EngineSwap.DoInstall(vehicle, engineId, engineConfig)
            end
        }
    }

    lib.registerContext({
        id = 'engine_swap_confirm',
        title = locale('confirm_install', engineConfig.name),
        menu = 'engine_swap_catalog',
        options = options
    })

    lib.showContext('engine_swap_confirm')
end

function EngineSwap.DoInstall(vehicle, engineId, engineConfig)
    if not VisualEffects.CheckHoodOpen(vehicle) then
        lib.notify({ title = locale('open_hood_first'), type = 'error' })
        return
    end

    VisualEffects.WeldingEffect(vehicle, engineConfig.installTime * 1000)

    local progress = lib.progressBar({
        duration = engineConfig.installTime * 1000,
        label = locale('engine_installing'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    })

    if progress then
        local netId = VehToNet(vehicle)
        local success = lib.callback.await('mechanic:server:installEngine', false, netId, engineId)

        if success then
            lib.notify({ title = locale('engine_installed_success'), type = 'success' })
        else
            lib.notify({ title = locale('engine_swap_failed'), type = 'error' })
        end
    end
end

function EngineSwap.RemoveEngine(vehicle)
    local confirm = lib.alertDialog({
        header = locale('remove_engine'),
        content = locale('engine_confirm_remove'),
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then return end

    local progress = lib.progressBar({
        duration = Config.EngineSwap.removeInstallTime * 1000,
        label = locale('engine_removing'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    })

    if progress then
        local netId = VehToNet(vehicle)
        local success = lib.callback.await('mechanic:server:removeEngine', false, netId)

        if success then
            stopSimulation()
            restoreHandling(vehicle)
            lib.notify({ title = locale('engine_removed_success'), type = 'success' })
        else
            lib.notify({ title = locale('engine_swap_failed'), type = 'error' })
        end
    end
end

AddStateBagChangeHandler('engineData', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    if value then
        local engineConfig = Config.Engines[value.engineId]
        if not engineConfig then return end
        local defaults = getVehicleDefaults(entity)
        local defaultEngine = Config.Engines[defaults.engine]
        if not defaultEngine then return end
        applyStaticHandling(entity, engineConfig, defaultEngine)
    else
        restoreHandling(entity)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopSimulation()
    handlingCache = {}
end)

CreateThread(function()
    while true do
        Wait(600000)
        for vehicle in pairs(handlingCache) do
            if not DoesEntityExist(vehicle) then
                handlingCache[vehicle] = nil
            end
        end
    end
end)

return EngineSwap

local Effects = {}

local function ensureHandlingCache(vehicle, cache, key, getter)
    local entry = cache[vehicle]

    if not entry then
        entry = {}
        cache[vehicle] = entry
    end

    if entry[key] == nil then
        entry[key] = getter(vehicle)
    end

    return entry
end

function Effects.applyBrake(vehicle, fluidLevel, handlingCache)
    local handling = ensureHandlingCache(vehicle, handlingCache, 'brakeForce', function(veh)
        return GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce')
    end)

    local state = Entity(vehicle).state

    if fluidLevel < 30 then
        local reducedBrakeForce = handling.brakeForce * 0.3
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', reducedBrakeForce)

        if not state.lowBrakeWarning then
            state:set('lowBrakeWarning', true, true)
            lib.notify({
                title = locale('low_brake_fluid'),
                description = locale('brakes_severely_reduced'),
                type = 'error',
                duration = 8000
            })
        end
    elseif fluidLevel < 50 then
        local reducedBrakeForce = handling.brakeForce * 0.6
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', reducedBrakeForce)

        if not state.lowBrakeWarning then
            state:set('lowBrakeWarning', true, true)
            lib.notify({
                title = locale('low_brake_fluid'),
                description = locale('brakes_reduced'),
                type = 'warning',
                duration = 6000
            })
        end
    else
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', handling.brakeForce)
        state:set('lowBrakeWarning', false, true)
    end
end

function Effects.applyEngine(vehicle, oilLevel, coolantLevel)
    local state = Entity(vehicle).state
    local engineTemp = state.engineTemp or 90

    if oilLevel < 30 then
        local currentHealth = GetVehicleEngineHealth(vehicle)
        SetVehicleEngineHealth(vehicle, currentHealth - 0.5)

        ModifyVehicleTopSpeed(vehicle, 0.7)

        if not state.lowOilWarning then
            state:set('lowOilWarning', true, true)
            lib.notify({
                title = locale('low_engine_oil'),
                description = locale('engine_damage_risk'),
                type = 'error',
                duration = 8000
            })
        end
    else
        ModifyVehicleTopSpeed(vehicle, 1.0)
        state:set('lowOilWarning', false, true)
    end

    if coolantLevel < 30 then
        engineTemp = math.min(engineTemp + 2.0, 150)
        state:set('engineTemp', engineTemp, true)

        if engineTemp > 120 then
            SetVehicleEngineOn(vehicle, false, true, false)

            lib.notify({
                title = locale('engine_overheated'),
                description = locale('engine_shutdown'),
                type = 'error',
                duration = 10000
            })

            SetVehicleEngineHealth(vehicle, -100.0)
        elseif not state.lowCoolantWarning then
            state:set('lowCoolantWarning', true, true)
            lib.notify({
                title = locale('low_coolant'),
                description = locale('engine_overheating'),
                type = 'warning',
                duration = 8000
            })
        end
    else
        if engineTemp > 90 then
            engineTemp = math.max(engineTemp - 0.5, 90)
            state:set('engineTemp', engineTemp, true)
        end
        state:set('lowCoolantWarning', false, true)
    end
end

function Effects.applySteering(vehicle, fluidLevel, handlingCache)
    local handling = ensureHandlingCache(vehicle, handlingCache, 'steeringLock', function(veh)
        return GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock')
    end)

    local state = Entity(vehicle).state

    if fluidLevel < 30 then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', 25.0)

        if not state.lowSteeringWarning then
            state:set('lowSteeringWarning', true, true)
            lib.notify({
                title = locale('low_power_steering'),
                description = locale('steering_difficulty'),
                type = 'warning',
                duration = 6000
            })
        end
    elseif fluidLevel < 50 then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', 35.0)

        if not state.lowSteeringWarning then
            state:set('lowSteeringWarning', true, true)
            lib.notify({
                title = locale('low_power_steering'),
                description = locale('steering_slightly_heavy'),
                type = 'info',
                duration = 5000
            })
        end
    else
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', handling.steeringLock)
        state:set('lowSteeringWarning', false, true)
    end
end

function Effects.applyTireWear(vehicle, tireWear, handlingCache)
    local handling = ensureHandlingCache(vehicle, handlingCache, 'traction', function(veh)
        return {
            max = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax'),
            min = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin')
        }
    end)

    local state = Entity(vehicle).state

    if tireWear > 80 then
        if math.random(1, 1000) <= 5 then
            local tireIndex = math.random(0, 3)
            SetVehicleTyreBurst(vehicle, tireIndex, false, 1000.0)

            lib.notify({
                title = locale('tire_blowout'),
                description = locale('tire_worn_out'),
                type = 'error',
                duration = 8000
            })
        end

        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', handling.traction.max * 0.7)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', handling.traction.min * 0.5)

        if not state.tireWearWarning then
            state:set('tireWearWarning', true, true)
            lib.notify({
                title = locale('tire_wear_critical'),
                description = locale('replace_tires_soon'),
                type = 'error',
                duration = 10000
            })
        end
    elseif tireWear > 60 then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', handling.traction.max * 0.85)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', handling.traction.min * 0.75)

        if not state.tireWearWarning then
            state:set('tireWearWarning', true, true)
            lib.notify({
                title = locale('tire_wear_high'),
                description = locale('consider_tire_replacement'),
                type = 'warning',
                duration = 8000
            })
        end
    else
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', handling.traction.max)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', handling.traction.min)
        state:set('tireWearWarning', false, true)
    end
end

function Effects.applyBattery(vehicle, batteryLevel)
    local state = Entity(vehicle).state

    if batteryLevel < 20 then
        if math.random(1, 100) <= 10 then
            SetVehicleEngineOn(vehicle, false, true, false)

            lib.notify({
                title = locale('battery_dead'),
                description = locale('vehicle_wont_start'),
                type = 'error',
                duration = 10000
            })
        end

        SetVehicleLightMultiplier(vehicle, 0.3)

        if not state.batteryWarning then
            state:set('batteryWarning', true, true)
            lib.notify({
                title = locale('battery_critical'),
                description = locale('charge_battery_soon'),
                type = 'error',
                duration = 8000
            })
        end
    elseif batteryLevel < 40 then
        SetVehicleLightMultiplier(vehicle, 0.7)

        if not state.batteryWarning then
            state:set('batteryWarning', true, true)
            lib.notify({
                title = locale('battery_low'),
                description = locale('battery_needs_attention'),
                type = 'warning',
                duration = 6000
            })
        end
    else
        SetVehicleLightMultiplier(vehicle, 1.0)
        state:set('batteryWarning', false, true)
    end
end

function Effects.applyGearbox(vehicle, gearBoxHealth)
    local state = Entity(vehicle).state

    if gearBoxHealth < 30 then
        if math.random(1, 100) <= 5 then
            local randomGear = math.random(-1, 6)
            SetVehicleGear(vehicle, randomGear)

            lib.notify({
                title = locale('gearbox_failure'),
                description = locale('gears_changing_randomly'),
                type = 'error',
                duration = 8000
            })
        end

        if not state.gearBoxWarning then
            state:set('gearBoxWarning', true, true)
            lib.notify({
                title = locale('gearbox_critical'),
                description = locale('transmission_failing'),
                type = 'error',
                duration = 10000
            })
        end
    elseif gearBoxHealth < 60 then
        if math.random(1, 200) <= 1 then
            SetVehicleGear(vehicle, GetVehicleCurrentGear(vehicle))
        end

        if not state.gearBoxWarning then
            state:set('gearBoxWarning', true, true)
            lib.notify({
                title = locale('gearbox_worn'),
                description = locale('gear_changes_slow'),
                type = 'warning',
                duration = 6000
            })
        end
    else
        state:set('gearBoxWarning', false, true)
    end
end

function Effects.restoreHandling(vehicle, handlingCache)
    local handling = handlingCache[vehicle]
    if not handling then return end

    if handling.brakeForce then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', handling.brakeForce)
    end

    if handling.steeringLock then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', handling.steeringLock)
    end

    if handling.traction then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', handling.traction.max)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', handling.traction.min)
    end

    handlingCache[vehicle] = nil
end

return Effects

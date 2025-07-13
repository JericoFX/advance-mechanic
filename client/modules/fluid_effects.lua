local FluidEffects = {}

local effectsThread = nil
local originalHandling = {}

function FluidEffects.Start()
    if effectsThread then return end
    
    effectsThread = CreateThread(function()
        while true do
            local vehicle = cache.vehicle
            
            if vehicle and cache.seat == -1 then
                local vehicleState = Entity(vehicle).state
                
                -- Get fluid levels
                local brakeFluid = vehicleState.brakeFluidLevel or 100
                local oilLevel = vehicleState.oilLevel or 100
                local coolantLevel = vehicleState.coolantLevel or 100
                local powerSteeringFluid = vehicleState.powerSteeringLevel or 100
                
                -- Apply effects
                FluidEffects.ApplyBrakeEffect(vehicle, brakeFluid)
                FluidEffects.ApplyEngineEffect(vehicle, oilLevel, coolantLevel)
                FluidEffects.ApplySteeringEffect(vehicle, powerSteeringFluid)
            end
            
            Wait(1000)
        end
    end)
end

function FluidEffects.Stop()
    if effectsThread then
        effectsThread = nil
    end
end

function FluidEffects.ApplyBrakeEffect(vehicle, fluidLevel)
    if not originalHandling[vehicle] then
        originalHandling[vehicle] = {
            brakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce')
        }
    end
    
    if fluidLevel < 30 then
        -- Frenos muy débiles
        local reducedBrakeForce = originalHandling[vehicle].brakeForce * 0.3
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', reducedBrakeForce)
        
        -- Show warning once
        if not Entity(vehicle).state.lowBrakeWarning then
            Entity(vehicle).state:set('lowBrakeWarning', true, true)
            lib.notify({
                title = locale('low_brake_fluid'),
                description = locale('brakes_severely_reduced'),
                type = 'error',
                duration = 8000
            })
        end
    elseif fluidLevel < 50 then
        -- Frenos reducidos
        local reducedBrakeForce = originalHandling[vehicle].brakeForce * 0.6
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', reducedBrakeForce)
        
        if not Entity(vehicle).state.lowBrakeWarning then
            Entity(vehicle).state:set('lowBrakeWarning', true, true)
            lib.notify({
                title = locale('low_brake_fluid'),
                description = locale('brakes_reduced'),
                type = 'warning',
                duration = 6000
            })
        end
    else
        -- Restaurar frenos normales
        if originalHandling[vehicle] then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', originalHandling[vehicle].brakeForce)
            Entity(vehicle).state:set('lowBrakeWarning', false, true)
        end
    end
end

function FluidEffects.ApplyEngineEffect(vehicle, oilLevel, coolantLevel)
    local engineTemp = Entity(vehicle).state.engineTemp or 90
    
    -- Efecto del aceite bajo
    if oilLevel < 30 then
        -- Aumentar desgaste del motor
        local currentHealth = GetVehicleEngineHealth(vehicle)
        SetVehicleEngineHealth(vehicle, currentHealth - 0.5)
        
        -- Reducir potencia
        ModifyVehicleTopSpeed(vehicle, 0.7)
        
        if not Entity(vehicle).state.lowOilWarning then
            Entity(vehicle).state:set('lowOilWarning', true, true)
            lib.notify({
                title = locale('low_engine_oil'),
                description = locale('engine_damage_risk'),
                type = 'error',
                duration = 8000
            })
        end
    else
        ModifyVehicleTopSpeed(vehicle, 1.0)
        Entity(vehicle).state:set('lowOilWarning', false, true)
    end
    
    -- Efecto del refrigerante bajo
    if coolantLevel < 30 then
        -- Aumentar temperatura del motor rápidamente
        engineTemp = math.min(engineTemp + 2.0, 150)
        Entity(vehicle).state:set('engineTemp', engineTemp, true)
        
        if engineTemp > 120 then
            -- Motor sobrecalentado
            SetVehicleEngineOn(vehicle, false, true, false)
            
            lib.notify({
                title = locale('engine_overheated'),
                description = locale('engine_shutdown'),
                type = 'error',
                duration = 10000
            })
            
            -- Humo del motor
            SetVehicleEngineHealth(vehicle, -100.0)
        elseif not Entity(vehicle).state.lowCoolantWarning then
            Entity(vehicle).state:set('lowCoolantWarning', true, true)
            lib.notify({
                title = locale('low_coolant'),
                description = locale('engine_overheating'),
                type = 'warning',
                duration = 8000
            })
        end
    else
        -- Enfriar el motor gradualmente
        if engineTemp > 90 then
            engineTemp = math.max(engineTemp - 0.5, 90)
            Entity(vehicle).state:set('engineTemp', engineTemp, true)
        end
        Entity(vehicle).state:set('lowCoolantWarning', false, true)
    end
end

function FluidEffects.ApplySteeringEffect(vehicle, fluidLevel)
    if fluidLevel < 30 then
        -- Dirección muy pesada
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', 25.0)
        
        if not Entity(vehicle).state.lowSteeringWarning then
            Entity(vehicle).state:set('lowSteeringWarning', true, true)
            lib.notify({
                title = locale('low_power_steering'),
                description = locale('steering_difficulty'),
                type = 'warning',
                duration = 6000
            })
        end
    elseif fluidLevel < 50 then
        -- Dirección ligeramente pesada
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', 35.0)
        
        if not Entity(vehicle).state.lowSteeringWarning then
            Entity(vehicle).state:set('lowSteeringWarning', true, true)
            lib.notify({
                title = locale('low_power_steering'),
                description = locale('steering_slightly_heavy'),
                type = 'info',
                duration = 5000
            })
        end
    else
        -- Restaurar dirección normal
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', 40.0)
        Entity(vehicle).state:set('lowSteeringWarning', false, true)
    end
end

function FluidEffects.Monitor()
    lib.onCache('vehicle', function(vehicle)
        if vehicle then
            FluidEffects.Start()
        else
            FluidEffects.Stop()
            originalHandling = {}
        end
    end)
    
    lib.onCache('seat', function(seat)
        if cache.vehicle and seat == -1 then
            FluidEffects.Start()
        elseif seat ~= -1 then
            FluidEffects.Stop()
        end
    end)
end

return FluidEffects

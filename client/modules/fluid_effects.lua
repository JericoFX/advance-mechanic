local FluidEffects = {}

local effectsThread = nil
local originalHandling = {}

function FluidEffects.Start()
    if effectsThread then return end
    
    -- Cargar datos iniciales del servidor
    local plate = GetVehicleNumberPlateText(cache.vehicle)
    lib.callback('mechanic:server:getVehicleFluidData', false, function(data)
        if data and cache.vehicle then
            local vehicleState = Entity(cache.vehicle).state
            vehicleState:set('oilLevel', data.oilLevel, true)
            vehicleState:set('coolantLevel', data.coolantLevel, true)
            vehicleState:set('brakeFluidLevel', data.brakeFluidLevel, true)
            vehicleState:set('transmissionFluidLevel', data.transmissionFluidLevel, true)
            vehicleState:set('powerSteeringLevel', data.powerSteeringLevel, true)
        end
    end, plate)
    
    effectsThread = CreateThread(function()
        local lastDegradation = 0
        local lastSync = 0
        
        while true do
            local vehicle = cache.vehicle
            
            if vehicle and cache.seat == -1 then
                local vehicleState = Entity(vehicle).state
                local currentTime = GetGameTimer()
                
                -- Get fluid levels
                local brakeFluid = vehicleState.brakeFluidLevel or 100
                local oilLevel = vehicleState.oilLevel or 100
                local coolantLevel = vehicleState.coolantLevel or 100
                local powerSteeringFluid = vehicleState.powerSteeringLevel or 100
                
                -- Apply effects
                FluidEffects.ApplyBrakeEffect(vehicle, brakeFluid)
                FluidEffects.ApplyEngineEffect(vehicle, oilLevel, coolantLevel)
                FluidEffects.ApplySteeringEffect(vehicle, powerSteeringFluid)
                
                -- Degradación automática cada 30 segundos
                if currentTime - lastDegradation > 30000 then
                    FluidEffects.DegradeFluidLevels(vehicle)
                    lastDegradation = currentTime
                end
                
                -- Sincronización con servidor cada 5 minutos
                if currentTime - lastSync > 300000 then
                    FluidEffects.SyncWithServer(vehicle)
                    lastSync = currentTime
                end
            end
            
            Wait(1000)
        end
    end)
end

function FluidEffects.Stop()
    if effectsThread then
        effectsThread = nil
    end
    
    -- Limpiar memoria de handling guardado
    for vehicle, _ in pairs(originalHandling) do
        if not DoesEntityExist(vehicle) then
            originalHandling[vehicle] = nil
        end
    end
    
    -- Sincronizar datos finales con el servidor si había un vehículo
    if cache.vehicle then
        local plate = GetVehicleNumberPlateText(cache.vehicle)
        local vehicleState = Entity(cache.vehicle).state
        local fluidData = {
            oilLevel = vehicleState.oilLevel or 100,
            coolantLevel = vehicleState.coolantLevel or 100,
            brakeFluidLevel = vehicleState.brakeFluidLevel or 100,
            transmissionFluidLevel = vehicleState.transmissionFluidLevel or 100,
            powerSteeringLevel = vehicleState.powerSteeringLevel or 100
        }
        TriggerServerEvent('mechanic:server:syncFluidLevels', plate, fluidData)
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

function FluidEffects.DegradeFluidLevels(vehicle)
    local vehicleState = Entity(vehicle).state
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local speed = GetEntitySpeed(vehicle) * 3.6 -- Convertir a km/h
    
    -- Degradación base
    local oilDegradation = 0.1
    local coolantDegradation = 0.1
    local brakeDegradation = 0.05
    local steeringDegradation = 0.05
    
    -- Aumentar degradación si el motor está dañado
    if engineHealth < 900 then
        oilDegradation = oilDegradation * 2
        coolantDegradation = coolantDegradation * 1.5
    end
    
    -- Aumentar degradación por alta velocidad
    if speed > 120 then
        oilDegradation = oilDegradation * 1.5
        coolantDegradation = coolantDegradation * 2
        brakeDegradation = brakeDegradation * 2
    end
    
    -- Aplicar degradación
    local currentOil = vehicleState.oilLevel or 100
    local currentCoolant = vehicleState.coolantLevel or 100
    local currentBrake = vehicleState.brakeFluidLevel or 100
    local currentSteering = vehicleState.powerSteeringLevel or 100
    
    vehicleState:set('oilLevel', math.max(0, currentOil - oilDegradation), true)
    vehicleState:set('coolantLevel', math.max(0, currentCoolant - coolantDegradation), true)
    vehicleState:set('brakeFluidLevel', math.max(0, currentBrake - brakeDegradation), true)
    vehicleState:set('powerSteeringLevel', math.max(0, currentSteering - steeringDegradation), true)
end

function FluidEffects.SyncWithServer(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    local vehicleState = Entity(vehicle).state
    
    local fluidData = {
        oilLevel = vehicleState.oilLevel or 100,
        coolantLevel = vehicleState.coolantLevel or 100,
        brakeFluidLevel = vehicleState.brakeFluidLevel or 100,
        transmissionFluidLevel = vehicleState.transmissionFluidLevel or 100,
        powerSteeringLevel = vehicleState.powerSteeringLevel or 100
    }
    
    TriggerServerEvent('mechanic:server:syncFluidLevels', plate, fluidData)
end

function FluidEffects.CleanupMemory()
    -- Limpiar vehículos que ya no existen
    local cleaned = 0
    for vehicle, _ in pairs(originalHandling) do
        if not DoesEntityExist(vehicle) then
            originalHandling[vehicle] = nil
            cleaned = cleaned + 1
        end
    end
    if cleaned > 0 then
        print(string.format('[FluidEffects] Cleaned %d stale vehicle entries', cleaned))
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
    
    -- Thread de limpieza de memoria cada 10 minutos
    CreateThread(function()
        while true do
            Wait(600000) -- 10 minutos
            FluidEffects.CleanupMemory()
        end
    end)
end

return FluidEffects

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
            vehicleState:set('tireWear', data.tireWear or 0, true)
            vehicleState:set('batteryLevel', data.batteryLevel or 100, true)
            vehicleState:set('gearBoxHealth', data.gearBoxHealth or 100, true)
        end
    end, plate)
    
    effectsThread = CreateThread(function()
        local lastDegradation = 0
        local lastSync = 0
        local lastMileage = 0
        
        while true do
            local vehicle = cache.vehicle
            
            if vehicle and cache.seat == -1 then
                local vehicleState = Entity(vehicle).state
                local currentTime = GetGameTimer()
                
                -- Get fluid and component levels
                local brakeFluid = vehicleState.brakeFluidLevel or 100
                local oilLevel = vehicleState.oilLevel or 100
                local coolantLevel = vehicleState.coolantLevel or 100
                local powerSteeringFluid = vehicleState.powerSteeringLevel or 100
                local tireWear = vehicleState.tireWear or 0
                local batteryLevel = vehicleState.batteryLevel or 100
                local gearBoxHealth = vehicleState.gearBoxHealth or 100
                local mileage = GetEntityCoords(vehicle).x + GetEntityCoords(vehicle).y -- Just as an example
                
                -- Apply effects
                FluidEffects.ApplyBrakeEffect(vehicle, brakeFluid)
                FluidEffects.ApplyEngineEffect(vehicle, oilLevel, coolantLevel)
                FluidEffects.ApplySteeringEffect(vehicle, powerSteeringFluid)
                FluidEffects.ApplyTireWearEffect(vehicle, tireWear)
                FluidEffects.ApplyBatteryEffect(vehicle, batteryLevel)
                FluidEffects.ApplyGearBoxEffect(vehicle, gearBoxHealth)
                
                -- Degradación automática cada 30 segundos y por kilometraje
                if currentTime - lastDegradation >= 30000 or math.abs(mileage - lastMileage) >= 1 then
                if currentTime - lastSync >= 300000 then
 1 then
                    FluidEffects.DegradeFluidLevels(vehicle)
                    FluidEffects.DegradeComponents(vehicle)
                    lastDegradation = currentTime
                    lastMileage = mileage
                end
                
                -- Sincronización con servidor cada 5 minutos
                if currentTime - lastSync  300000 then
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

function FluidEffects.ApplyTireWearEffect(vehicle, tireWear)
    if tireWear > 80 then
        -- Ruedas muy desgastadas - riesgo de explosión
        if math.random(1, 1000) <= 5 then -- 0.5% de probabilidad
            local tireIndex = math.random(0, 3)
            SetVehicleTyreBurst(vehicle, tireIndex, false, 1000.0)
            
            lib.notify({
                title = locale('tire_blowout'),
                description = locale('tire_worn_out'),
                type = 'error',
                duration = 8000
            })
        end
        
        -- Reducir tracción
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', 0.7)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', 0.5)
        
        if not Entity(vehicle).state.tireWearWarning then
            Entity(vehicle).state:set('tireWearWarning', true, true)
            lib.notify({
                title = locale('tire_wear_critical'),
                description = locale('replace_tires_soon'),
                type = 'error',
                duration = 10000
            })
        end
    elseif tireWear > 60 then
        -- Ruedas desgastadas - tracción reducida
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', 0.85)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', 0.75)
        
        if not Entity(vehicle).state.tireWearWarning then
            Entity(vehicle).state:set('tireWearWarning', true, true)
            lib.notify({
                title = locale('tire_wear_high'),
                description = locale('consider_tire_replacement'),
                type = 'warning',
                duration = 8000
            })
        end
    else
        -- Ruedas en buen estado
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', 1.0)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', 1.0)
        Entity(vehicle).state:set('tireWearWarning', false, true)
    end
end

function FluidEffects.ApplyBatteryEffect(vehicle, batteryLevel)
    if batteryLevel < 20 then
        -- Batería muy baja - riesgo de apagado
        if math.random(1, 100) <= 10 then -- 10% de probabilidad cada segundo
            SetVehicleEngineOn(vehicle, false, true, false)
            
            lib.notify({
                title = locale('battery_dead'),
                description = locale('vehicle_wont_start'),
                type = 'error',
                duration = 10000
            })
        end
        
        -- Luces más débiles
        SetVehicleLightMultiplier(vehicle, 0.3)
        
        if not Entity(vehicle).state.batteryWarning then
            Entity(vehicle).state:set('batteryWarning', true, true)
            lib.notify({
                title = locale('battery_critical'),
                description = locale('charge_battery_soon'),
                type = 'error',
                duration = 8000
            })
        end
    elseif batteryLevel < 40 then
        -- Batería baja - luces débiles
        SetVehicleLightMultiplier(vehicle, 0.7)
        
        if not Entity(vehicle).state.batteryWarning then
            Entity(vehicle).state:set('batteryWarning', true, true)
            lib.notify({
                title = locale('battery_low'),
                description = locale('battery_needs_attention'),
                type = 'warning',
                duration = 6000
            })
        end
    else
        -- Batería en buen estado
        SetVehicleLightMultiplier(vehicle, 1.0)
        Entity(vehicle).state:set('batteryWarning', false, true)
    end
end

function FluidEffects.ApplyGearBoxEffect(vehicle, gearBoxHealth)
    if gearBoxHealth < 30 then
        -- Caja de cambios muy dañada
        if math.random(1, 100) <= 5 then -- 5% de probabilidad
            -- Cambio aleatorio de marcha
            local randomGear = math.random(-1, 6)
            SetVehicleGear(vehicle, randomGear)
            
            lib.notify({
                title = locale('gearbox_failure'),
                description = locale('gears_changing_randomly'),
                type = 'error',
                duration = 8000
            })
        end
        
        if not Entity(vehicle).state.gearBoxWarning then
            Entity(vehicle).state:set('gearBoxWarning', true, true)
            lib.notify({
                title = locale('gearbox_critical'),
                description = locale('transmission_failing'),
                type = 'error',
                duration = 10000
            })
        end
    elseif gearBoxHealth < 60 then
        -- Caja de cambios dañada - cambios lentos
        if math.random(1, 200) <= 1 then -- Menor probabilidad de fallo
            SetVehicleGear(vehicle, GetVehicleCurrentGear(vehicle)) -- Mantener marcha actual
        end
        
        if not Entity(vehicle).state.gearBoxWarning then
            Entity(vehicle).state:set('gearBoxWarning', true, true)
            lib.notify({
                title = locale('gearbox_worn'),
                description = locale('gear_changes_slow'),
                type = 'warning',
                duration = 6000
            })
        end
    else
        -- Caja de cambios en buen estado
        Entity(vehicle).state:set('gearBoxWarning', false, true)
    end
end

function FluidEffects.DegradeComponents(vehicle)
    local vehicleState = Entity(vehicle).state
    local speed = GetEntitySpeed(vehicle) * 3.6
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    -- Desgaste de neumáticos basado en velocidad y superficie
    local tireWearRate = 0.01 -- Base rate
    if speed > 80 then
        tireWearRate = tireWearRate * 2
    end
    if speed > 150 then
        tireWearRate = tireWearRate * 3
    end
    
    -- Superficie del terreno
    local surfaceHash = GetVehicleWheelSurfaceMaterial(vehicle, 0)
    if surfaceHash == GetHashKey('SAND') or surfaceHash == GetHashKey('ROCK') then
        tireWearRate = tireWearRate * 1.5
    end
    
    local currentTireWear = vehicleState.tireWear or 0
    vehicleState:set('tireWear', math.min(100, currentTireWear + tireWearRate), true)
    
    -- Desgaste de batería
    local batteryDrainRate = 0.02
    if engineHealth < 800 then
        batteryDrainRate = batteryDrainRate * 2
    end
    if speed == 0 and GetIsVehicleEngineRunning(vehicle) then
        batteryDrainRate = batteryDrainRate * 1.5 -- Ralentí consume batería
    end
    
    local currentBattery = vehicleState.batteryLevel or 100
    vehicleState:set('batteryLevel', math.max(0, currentBattery - batteryDrainRate), true)
    
    -- Desgaste de caja de cambios
    local gearBoxDamageRate = 0.01
    if speed > 120 then
        gearBoxDamageRate = gearBoxDamageRate * 2
    end
    if bodyHealth < 800 then
        gearBoxDamageRate = gearBoxDamageRate * 1.5
    end
    
    local currentGearBox = vehicleState.gearBoxHealth or 100
    vehicleState:set('gearBoxHealth', math.max(0, currentGearBox - gearBoxDamageRate), true)
end

-- Función para detectar colisiones
function FluidEffects.OnVehicleCollision(vehicle, damage)
    local vehicleState = Entity(vehicle).state
    
    -- Daño a la batería por impacto
    local batteryDamage = damage * 0.1
    local currentBattery = vehicleState.batteryLevel or 100
    vehicleState:set('batteryLevel', math.max(0, currentBattery - batteryDamage), true)
    
    -- Daño a la caja de cambios
    local gearBoxDamage = damage * 0.15
    local currentGearBox = vehicleState.gearBoxHealth or 100
    vehicleState:set('gearBoxHealth', math.max(0, currentGearBox - gearBoxDamage), true)
    
    -- Daño a los neumáticos
    if damage > 50 then
        local tireDamage = damage * 0.2
        local currentTireWear = vehicleState.tireWear or 0
        vehicleState:set('tireWear', math.min(100, currentTireWear + tireDamage), true)
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
    
    -- Thread de detección de colisiones
    CreateThread(function()
        local lastBodyHealth = {}
        
        while true do
            if cache.vehicle and cache.seat == -1 then
                local vehicle = cache.vehicle
                local currentBodyHealth = GetVehicleBodyHealth(vehicle)
                local plate = GetVehicleNumberPlateText(vehicle)
                
                if lastBodyHealth[plate] then
                    local damage = lastBodyHealth[plate] - currentBodyHealth
                    if damage > 20 then -- Colisión significativa
                        FluidEffects.OnVehicleCollision(vehicle, damage)
                    end
                end
                
                lastBodyHealth[plate] = currentBodyHealth
            end
            
            Wait(500) -- Check every 0.5 seconds
        end
    end)
end

return FluidEffects

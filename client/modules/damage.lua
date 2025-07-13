local Damage = {}

local damageCheckTime = 0
local monitoringThread = nil

function Damage.StartMonitoring(vehicle)
    if monitoringThread then return end
    
    damageCheckTime = GetGameTimer() + 5000
    
    monitoringThread = CreateThread(function()
        while cache.vehicle == vehicle and cache.seat == -1 do
            if GetGameTimer() > damageCheckTime then
                local speed = GetEntitySpeed(vehicle) * 3.6
                
                if HasEntityCollidedWithAnything(vehicle) and speed > 20 then
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local impactData = Damage.AnalyzeImpact(vehicle)
                    
                    TriggerServerEvent('mechanic:server:vehicleDamaged', plate, impactData)
                    damageCheckTime = GetGameTimer() + 3000
                    
                    if impactData.side == 'front' and speed > 50 then
                        SetVehicleEngineHealth(vehicle, GetVehicleEngineHealth(vehicle) - 100)
                    end
                    
                    if impactData.wheelDamage and speed > 30 then
                        Damage.ApplyWheelMisalignment(vehicle, impactData.damagedWheel)
                    end
                end
            end
            
            Wait(100)
        end
        
        monitoringThread = nil
    end)
end

function Damage.StopMonitoring()
    if monitoringThread then
        monitoringThread = nil
    end
end

function Damage.Monitor()
    lib.onCache('vehicle', function(vehicle)
        if vehicle then
            Damage.StartMonitoring(vehicle)
            Damage.ApplySteeringCorrection()
        else
            Damage.StopMonitoring()
        end
    end)
    
    lib.onCache('seat', function(seat)
        if cache.vehicle and seat == -1 then
            Damage.StartMonitoring(cache.vehicle)
        elseif seat ~= -1 then
            Damage.StopMonitoring()
        end
    end)
end

function Damage.AnalyzeImpact(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)
    local impactData = {
        side = nil,
        severity = 0,
        wheelDamage = false,
        damagedWheel = nil
    }
    
    -- Check each corner of the vehicle
    local corners = {
        {offset = vec3(min.x, max.y, 0.0), side = 'front-left', wheel = 0},
        {offset = vec3(max.x, max.y, 0.0), side = 'front-right', wheel = 1},
        {offset = vec3(min.x, min.y, 0.0), side = 'rear-left', wheel = 4},
        {offset = vec3(max.x, min.y, 0.0), side = 'rear-right', wheel = 5}
    }
    
    local maxDeformation = 0
    for _, corner in ipairs(corners) do
        local deformation = GetVehicleDeformationAtPos(vehicle, corner.offset.x, corner.offset.y, corner.offset.z)
        if #deformation > maxDeformation then
            maxDeformation = #deformation
            impactData.side = corner.side
            
            -- Check if wheel is damaged
            if IsVehicleTyreBurst(vehicle, corner.wheel, false) then
                impactData.wheelDamage = true
                impactData.damagedWheel = corner.wheel
            end
        end
    end
    
    impactData.severity = maxDeformation
    
    -- Update vehicle state
    local vehicleState = Entity(vehicle).state
    vehicleState:set('damageData', impactData, true)
    
    return impactData
end

function Damage.ApplyWheelMisalignment(vehicle, wheelIndex)
    -- Apply steering bias to simulate misalignment
    local steeringBias = 0.0
    
    if wheelIndex == 0 or wheelIndex == 4 then -- Left wheels
        steeringBias = -0.2
    elseif wheelIndex == 1 or wheelIndex == 5 then -- Right wheels
        steeringBias = 0.2
    end
    
    -- Store misalignment in state bag
    local vehicleState = Entity(vehicle).state
    vehicleState:set('wheelMisalignment', {
        wheel = wheelIndex,
        bias = steeringBias
    }, true)
    
    -- Apply visual effect
    SetVehicleWheelXOffset(vehicle, wheelIndex, steeringBias * 0.1)
    
    lib.notify({
        title = locale('wheel_misaligned'),
        description = locale('vehicle_pulls_to_side'),
        type = 'warning'
    })
end

local steeringThread = nil

function Damage.ApplySteeringCorrection()
    if steeringThread then return end
    
    local vehicle = cache.vehicle
    if not vehicle then return end
    
    local vehicleState = Entity(vehicle).state
    local misalignment = vehicleState.wheelMisalignment
    
    if not misalignment or not misalignment.bias then return end
    
    steeringThread = CreateThread(function()
        while cache.vehicle == vehicle do
            SetVehicleSteerBias(vehicle, misalignment.bias)
            Wait(0)
        end
        steeringThread = nil
    end)
end

return Damage

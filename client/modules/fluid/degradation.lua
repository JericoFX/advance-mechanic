local Degradation = {}

function Degradation.applyComponentWear(vehicle)
    local state = Entity(vehicle).state
    local speed = GetEntitySpeed(vehicle) * 3.6
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)

    local tireWearRate = 0.01
    if speed > 80 then
        tireWearRate = tireWearRate * 2
    end
    if speed > 150 then
        tireWearRate = tireWearRate * 3
    end

    local surfaceHash = GetVehicleWheelSurfaceMaterial(vehicle, 0)
    if surfaceHash == GetHashKey('SAND') or surfaceHash == GetHashKey('ROCK') then
        tireWearRate = tireWearRate * 1.5
    end

    local currentTireWear = state.tireWear or 0
    state:set('tireWear', math.min(100, currentTireWear + tireWearRate), true)

    local batteryDrainRate = 0.02
    if engineHealth < 800 then
        batteryDrainRate = batteryDrainRate * 2
    end
    if speed == 0 and GetIsVehicleEngineRunning(vehicle) then
        batteryDrainRate = batteryDrainRate * 1.5
    end

    local currentBattery = state.batteryLevel or 100
    state:set('batteryLevel', math.max(0, currentBattery - batteryDrainRate), true)

    local gearBoxDamageRate = 0.01
    if speed > 120 then
        gearBoxDamageRate = gearBoxDamageRate * 2
    end
    if bodyHealth < 800 then
        gearBoxDamageRate = gearBoxDamageRate * 1.5
    end

    local currentGearBox = state.gearBoxHealth or 100
    state:set('gearBoxHealth', math.max(0, currentGearBox - gearBoxDamageRate), true)
end

function Degradation.applyFluidLoss(vehicle)
    local state = Entity(vehicle).state
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local speed = GetEntitySpeed(vehicle) * 3.6

    local oilDegradation = 0.1
    local coolantDegradation = 0.1
    local brakeDegradation = 0.05
    local steeringDegradation = 0.05

    if engineHealth < 900 then
        oilDegradation = oilDegradation * 2
        coolantDegradation = coolantDegradation * 1.5
    end

    if speed > 120 then
        oilDegradation = oilDegradation * 1.5
        coolantDegradation = coolantDegradation * 2
        brakeDegradation = brakeDegradation * 2
    end

    local currentOil = state.oilLevel or 100
    local currentCoolant = state.coolantLevel or 100
    local currentBrake = state.brakeFluidLevel or 100
    local currentSteering = state.powerSteeringLevel or 100

    state:set('oilLevel', math.max(0, currentOil - oilDegradation), true)
    state:set('coolantLevel', math.max(0, currentCoolant - coolantDegradation), true)
    state:set('brakeFluidLevel', math.max(0, currentBrake - brakeDegradation), true)
    state:set('powerSteeringLevel', math.max(0, currentSteering - steeringDegradation), true)
end

function Degradation.onCollision(vehicle, damage)
    local state = Entity(vehicle).state

    local batteryDamage = damage * 0.1
    local currentBattery = state.batteryLevel or 100
    state:set('batteryLevel', math.max(0, currentBattery - batteryDamage), true)

    local gearBoxDamage = damage * 0.15
    local currentGearBox = state.gearBoxHealth or 100
    state:set('gearBoxHealth', math.max(0, currentGearBox - gearBoxDamage), true)

    if damage > 50 then
        local tireDamage = damage * 0.2
        local currentTireWear = state.tireWear or 0
        state:set('tireWear', math.min(100, currentTireWear + tireDamage), true)
    end
end

return Degradation

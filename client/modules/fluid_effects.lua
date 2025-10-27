local FluidEffects = {}

local Effects = require 'client.modules.fluid.effects'
local Degradation = require 'client.modules.fluid.degradation'
local State = require 'client.modules.fluid.state'

local handlingCache = {}
local effectsThreadActive = false
local trackedVehicle = nil
local cleanupThreadStarted = false
local collisionWatcherStarted = false

local function startCleanupThread()
    if cleanupThreadStarted then return end
    cleanupThreadStarted = true

    CreateThread(function()
        while true do
            Wait(600000)
            State.cleanupHandlingCache(handlingCache)
        end
    end)
end

local function startCollisionWatcher()
    if collisionWatcherStarted then return end
    collisionWatcherStarted = true

    CreateThread(function()
        local lastBodyHealth = {}

        while true do
            if effectsThreadActive and trackedVehicle and DoesEntityExist(trackedVehicle) then
                local vehicle = trackedVehicle
                local plate = GetVehicleNumberPlateText(vehicle) or 'unknown'
                local currentBodyHealth = GetVehicleBodyHealth(vehicle)
                local previousBodyHealth = lastBodyHealth[plate]

                if previousBodyHealth then
                    local damage = previousBodyHealth - currentBodyHealth
                    if damage > 20 then
                        Degradation.onCollision(vehicle, damage)
                    end
                end

                lastBodyHealth[plate] = currentBodyHealth
            else
                lastBodyHealth = {}
            end

            Wait(500)
        end
    end)
end

local function startEffectsThread(vehicle)
    if effectsThreadActive and trackedVehicle == vehicle then return end

    if effectsThreadActive then
        FluidEffects.Stop()
    end

    if not DoesEntityExist(vehicle) then return end

    trackedVehicle = vehicle

    local plate = GetVehicleNumberPlateText(vehicle)
    local initialData = State.fetchInitialData(plate)
    State.applyInitialData(vehicle, initialData)

    effectsThreadActive = true

    CreateThread(function()
        local lastDegradation = GetGameTimer()
        local lastSync = GetGameTimer()
        local lastMileage = 0.0

        while effectsThreadActive and trackedVehicle == vehicle do
            local waitMs = 1000

            if cache.vehicle == vehicle and cache.seat == -1 and DoesEntityExist(vehicle) then
                local state = Entity(vehicle).state

                Effects.applyBrake(vehicle, state.brakeFluidLevel or 100, handlingCache)
                Effects.applyEngine(vehicle, state.oilLevel or 100, state.coolantLevel or 100)
                Effects.applySteering(vehicle, state.powerSteeringLevel or 100, handlingCache)
                Effects.applyTireWear(vehicle, state.tireWear or 0, handlingCache)
                Effects.applyBattery(vehicle, state.batteryLevel or 100)
                Effects.applyGearbox(vehicle, state.gearBoxHealth or 100)

                local coords = GetEntityCoords(vehicle)
                local mileage = coords.x + coords.y
                local currentTime = GetGameTimer()

                if currentTime - lastDegradation >= 30000 or math.abs(mileage - lastMileage) >= 1 then
                    Degradation.applyFluidLoss(vehicle)
                    Degradation.applyComponentWear(vehicle)
                    lastDegradation = currentTime
                    lastMileage = mileage
                end

                if currentTime - lastSync >= 300000 then
                    State.pushToServer(vehicle)
                    lastSync = currentTime
                end
            else
                waitMs = 1500
            end

            Wait(waitMs)
        end
    end)
end

function FluidEffects.Start(vehicle)
    if not vehicle or cache.seat ~= -1 then return end

    startCleanupThread()
    startCollisionWatcher()
    startEffectsThread(vehicle)
end

function FluidEffects.Stop()
    if not effectsThreadActive then return end

    effectsThreadActive = false

    local vehicle = trackedVehicle
    trackedVehicle = nil

    if vehicle and DoesEntityExist(vehicle) then
        State.pushToServer(vehicle)
        Effects.restoreHandling(vehicle, handlingCache)
    end
end

function FluidEffects.Monitor()
    startCleanupThread()
    startCollisionWatcher()

    lib.onCache('vehicle', function(vehicle)
        if vehicle and cache.seat == -1 then
            FluidEffects.Start(vehicle)
        else
            FluidEffects.Stop()
        end
    end)

    lib.onCache('seat', function(seat)
        if seat == -1 and cache.vehicle then
            FluidEffects.Start(cache.vehicle)
        else
            FluidEffects.Stop()
        end
    end)
end

return FluidEffects

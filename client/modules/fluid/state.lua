local State = {}

function State.fetchInitialData(plate)
    if not plate or plate == '' then return nil end
    return lib.callback.await('mechanic:server:getVehicleFluidData', false, plate)
end

function State.applyInitialData(vehicle, data)
    if not data or not DoesEntityExist(vehicle) then return end

    local state = Entity(vehicle).state
    state:set('oilLevel', data.oilLevel or 100, true)
    state:set('coolantLevel', data.coolantLevel or 100, true)
    state:set('brakeFluidLevel', data.brakeFluidLevel or 100, true)
    state:set('transmissionFluidLevel', data.transmissionFluidLevel or 100, true)
    state:set('powerSteeringLevel', data.powerSteeringLevel or 100, true)
    state:set('tireWear', data.tireWear or 0, true)
    state:set('batteryLevel', data.batteryLevel or 100, true)
    state:set('gearBoxHealth', data.gearBoxHealth or 100, true)
end

local function collectFluidData(vehicle)
    local state = Entity(vehicle).state

    return {
        oilLevel = state.oilLevel or 100,
        coolantLevel = state.coolantLevel or 100,
        brakeFluidLevel = state.brakeFluidLevel or 100,
        transmissionFluidLevel = state.transmissionFluidLevel or 100,
        powerSteeringLevel = state.powerSteeringLevel or 100,
        tireWear = state.tireWear or 0,
        batteryLevel = state.batteryLevel or 100,
        gearBoxHealth = state.gearBoxHealth or 100
    }
end

function State.pushToServer(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate or plate == '' then return end

    TriggerServerEvent('mechanic:server:syncFluidLevels', plate, collectFluidData(vehicle))
end

function State.cleanupHandlingCache(cache)
    local cleaned = 0

    for vehicle in pairs(cache) do
        if not DoesEntityExist(vehicle) then
            cache[vehicle] = nil
            cleaned = cleaned + 1
        end
    end

    if cleaned > 0 then
        print(string.format('[FluidEffects] Cleaned %d stale vehicle entries', cleaned))
    end
end

return State

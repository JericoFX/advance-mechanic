local Towing = {}

local attachedVehicle = nil
local winchActive = false

function Towing.AttachVehicle(towTruck, vehicle)
    if not DoesEntityExist(vehicle) then return end
    if not DoesEntityExist(towTruck) then return end
    
    -- Check distance and alignment
    local towBoneIndex = GetEntityBoneIndexByName(towTruck, Config.Towing.vehicles.towtruck.hookBone)
    local towCoords = GetWorldPositionOfEntityBone(towTruck, towBoneIndex)
    local vehCoords = GetEntityCoords(vehicle)
    
    if #(towCoords - vehCoords) > Config.Towing.maxTowDistance then
        lib.notify({
            title = locale('vehicle_too_far'),
            type = 'error'
        })
        return
    end
    
    if attachedVehicle then
        lib.notify({
            title = locale('another_vehicle_attached'),
            type = 'error'
        })
        return
    end
    
    -- Attach vehicle
    AttachEntityToEntity(vehicle, towTruck, towBoneIndex, Config.Towing.vehicles.towtruck.hookOffset.x, Config.Towing.vehicles.towtruck.hookOffset.y, Config.Towing.vehicles.towtruck.hookOffset.z, 0.0, 0.0, 0.0, false, false, false, true, 20, true)
    attachedVehicle = vehicle
    winchActive = true

    local vehicleState = Entity(vehicle).state
    vehicleState:set('towed', true, true)
    
    lib.notify({
        title = locale('vehicle_attached'),
        type = 'success'
    })
end

function Towing.DetachVehicle(towTruck)
    if not attachedVehicle then return end

    DetachEntity(attachedVehicle, true, false)
    local vehicleState = Entity(attachedVehicle).state
    vehicleState:set('towed', false, true)
    attachedVehicle = nil
    winchActive = false
    
    lib.notify({
        title = locale('vehicle_detached'),
        type = 'success'
    })
end

function Towing.ControlWinch(action)
    if not attachedVehicle or not winchActive then return end
    
    -- Implement winch controls
    if action == 'up' then
        -- Move the vehicle closer
        local offset = vec3(Config.Towing.vehicles.towtruck.winchSpeed, 0.0, 0.0)
        ApplyForceToEntity(attachedVehicle, 1, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, true, true, false, true, true)
    elseif action == 'down' then
        -- Move the vehicle away
        local offset = vec3(-Config.Towing.vehicles.towtruck.winchSpeed, 0.0, 0.0)
        ApplyForceToEntity(attachedVehicle, 1, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, true, true, false, true, true)
    end
end

-- Key bindings for winch control
local function RegisterWinchControls()
    lib.addKeybind({
        name = 'towing_winch_up',
        description = locale('winch_pull_up'),
        defaultKey = 'UP',
        onPressed = function()
            if winchActive and cache.vehicle then
                Towing.ControlWinch('up')
            end
        end
    })
    
    lib.addKeybind({
        name = 'towing_winch_down',
        description = locale('winch_release'),
        defaultKey = 'DOWN',
        onPressed = function()
            if winchActive and cache.vehicle then
                Towing.ControlWinch('down')
            end
        end
    })
    
    lib.addKeybind({
        name = 'towing_detach',
        description = locale('detach_vehicle'),
        defaultKey = 'E',
        onPressed = function()
            if winchActive and cache.vehicle then
                Towing.DetachVehicle(cache.vehicle)
            end
        end
    })
end

RegisterWinchControls()

return Towing

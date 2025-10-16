local Towing = {}

local attachedVehicle = nil
local winchActive = false
local currentTowConfig = nil
local currentTowTruck = nil

local function createVector(x, y, z)
    if type(vec3) == 'function' then
        return vec3(x, y, z)
    end

    return vector3(x, y, z)
end

local ZERO_VECTOR = createVector(0.0, 0.0, 0.0)

local function getBoneIndex(entity, boneName)
    if not boneName then return 0 end
    local index = GetEntityBoneIndexByName(entity, boneName)
    if index == -1 then return 0 end
    return index
end

local function getAttachmentSettings(config)
    local offset
    local rotation
    local boneName

    if config.type == 'flatbed' then
        boneName = config.bedBone or config.hookBone or 'bodyshell'
        offset = config.bedOffset or config.hookOffset or createVector(0.0, -1.5, 1.0)
        rotation = config.bedRotation or config.hookRotation or ZERO_VECTOR
    elseif config.type == 'boom' then
        boneName = config.boomBone or config.hookBone or 'misc_a'
        offset = config.boomOffset or config.hookOffset or createVector(0.0, -3.0, 1.0)
        rotation = config.boomRotation or config.hookRotation or ZERO_VECTOR
    elseif config.type == 'forklift' then
        boneName = config.liftBone or config.hookBone or 'forks'
        offset = config.liftOffset or config.hookOffset or createVector(0.0, 1.0, 0.1)
        rotation = config.liftRotation or config.hookRotation or ZERO_VECTOR
    else
        boneName = config.hookBone or 'misc_a'
        offset = config.hookOffset or createVector(0.0, -2.0, 0.5)
        rotation = config.hookRotation or ZERO_VECTOR
    end

    return boneName, offset or ZERO_VECTOR, rotation or ZERO_VECTOR
end

local function getMaxTowDistance(config)
    return (config and config.maxTowDistance) or Config.Towing.maxTowDistance
end

local function supportsWinch(config)
    return config and config.winchSpeed and config.winchSpeed > 0
end

function Towing.AttachVehicle(towTruck, vehicle, towConfig)
    if not DoesEntityExist(vehicle) then return end
    if not DoesEntityExist(towTruck) then return end
    if not towConfig then return end

    -- Check distance and alignment
    local boneName, offset, rotation = getAttachmentSettings(towConfig)
    local towBoneIndex = getBoneIndex(towTruck, boneName)
    local towCoords = GetOffsetFromEntityInWorldCoords(towTruck, offset.x, offset.y, offset.z)
    local vehCoords = GetEntityCoords(vehicle)

    if #(towCoords - vehCoords) > getMaxTowDistance(towConfig) then
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
    AttachEntityToEntity(vehicle, towTruck, towBoneIndex, offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, false, false, false, true, 20, true)
    attachedVehicle = vehicle
    currentTowTruck = towTruck
    currentTowConfig = towConfig
    winchActive = supportsWinch(towConfig)

    local vehicleState = Entity(vehicle).state
    vehicleState:set('towed', true, true)

    lib.notify({
        title = locale('vehicle_attached'),
        type = 'success'
    })
end

function Towing.DetachVehicle(towTruck)
    if not attachedVehicle then return end

    if towTruck and currentTowTruck and towTruck ~= currentTowTruck then
        return
    end

    DetachEntity(attachedVehicle, true, false)
    local vehicleState = Entity(attachedVehicle).state
    vehicleState:set('towed', false, true)
    attachedVehicle = nil
    winchActive = false
    currentTowTruck = nil
    currentTowConfig = nil

    lib.notify({
        title = locale('vehicle_detached'),
        type = 'success'
    })
end

function Towing.ControlWinch(action)
    if not attachedVehicle or not winchActive then return end
    if not currentTowConfig then return end
    if not currentTowTruck then return end

    local winchSpeed = currentTowConfig.winchSpeed or 0.0
    if winchSpeed <= 0.0 then return end

    -- Implement winch controls
    if action == 'up' then
        local towCoords = GetEntityCoords(currentTowTruck)
        local vehCoords = GetEntityCoords(attachedVehicle)
        local direction = towCoords - vehCoords
        local distance = #direction
        if distance > 0.0 then
            local normalized = createVector(direction.x / distance, direction.y / distance, direction.z / distance)
            local force = createVector(normalized.x * winchSpeed, normalized.y * winchSpeed, normalized.z * winchSpeed)
            ApplyForceToEntity(attachedVehicle, 1, force.x, force.y, force.z, 0.0, 0.0, 0.0, false, true, true, false, true, true)
        end
    elseif action == 'down' then
        local towCoords = GetEntityCoords(currentTowTruck)
        local vehCoords = GetEntityCoords(attachedVehicle)
        local direction = vehCoords - towCoords
        local distance = #direction
        if distance > 0.0 then
            local normalized = createVector(direction.x / distance, direction.y / distance, direction.z / distance)
            local force = createVector(normalized.x * winchSpeed, normalized.y * winchSpeed, normalized.z * winchSpeed)
            ApplyForceToEntity(attachedVehicle, 1, force.x, force.y, force.z, 0.0, 0.0, 0.0, false, true, true, false, true, true)
        end
    end
end

-- Key bindings for winch control
local function RegisterWinchControls()
    lib.addKeybind({
        name = 'towing_winch_up',
        description = locale('winch_pull_up'),
        defaultKey = 'UP',
        onPressed = function()
            if winchActive and cache.vehicle and cache.vehicle == currentTowTruck then
                Towing.ControlWinch('up')
            end
        end
    })
    
    lib.addKeybind({
        name = 'towing_winch_down',
        description = locale('winch_release'),
        defaultKey = 'DOWN',
        onPressed = function()
            if winchActive and cache.vehicle and cache.vehicle == currentTowTruck then
                Towing.ControlWinch('down')
            end
        end
    })
    
    lib.addKeybind({
        name = 'towing_detach',
        description = locale('detach_vehicle'),
        defaultKey = 'E',
        onPressed = function()
            if attachedVehicle and cache.vehicle and cache.vehicle == currentTowTruck then
                Towing.DetachVehicle(cache.vehicle)
            end
        end
    })
end

RegisterWinchControls()

return Towing

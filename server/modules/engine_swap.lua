local EngineSwap = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

---@param engineId string
---@return table|nil
local function getEngineConfig(engineId)
    if type(engineId) ~= 'string' then return nil end
    return Config.Engines[engineId]
end

---@param vehicle number
---@return table
local function getVehicleDefaults(vehicle)
    local class = GetVehicleClass(vehicle)
    return Config.VehicleClassDefaults[class] or Config.VehicleClassDefaults[0]
end

---@param plate string
---@return table|nil
function EngineSwap.GetData(plate)
    local result = MySQL.query.await('SELECT engine_id, wear, temperature, total_km FROM vehicle_engines WHERE plate = ?', { plate })
    if result and result[1] then
        return result[1]
    end
    return nil
end

---@param plate string
---@param engineId string
---@param installedBy string
---@return boolean
function EngineSwap.Install(plate, engineId, installedBy)
    local existing = EngineSwap.GetData(plate)
    if existing then
        return MySQL.update.await(
            'UPDATE vehicle_engines SET engine_id = ?, wear = 0.00, temperature = 20.00, total_km = 0.00, installed_at = CURRENT_TIMESTAMP, installed_by = ? WHERE plate = ?',
            { engineId, installedBy, plate }
        ) > 0
    else
        return MySQL.insert.await(
            'INSERT INTO vehicle_engines (plate, engine_id, installed_by) VALUES (?, ?, ?)',
            { plate, engineId, installedBy }
        ) > 0
    end
end

---@param plate string
---@return boolean
function EngineSwap.Remove(plate)
    MySQL.query.await('DELETE FROM vehicle_engines WHERE plate = ?', { plate })
    return true
end

---@param plate string
---@param wear number
---@param temperature number
---@param totalKm number
function EngineSwap.SyncData(plate, wear, temperature, totalKm)
    MySQL.update('UPDATE vehicle_engines SET wear = ?, temperature = ?, total_km = ? WHERE plate = ?', {
        wear, temperature, totalKm, plate
    })
end

---@param source number
---@param requiredParts table
---@return boolean
local function hasRequiredParts(source, requiredParts)
    for _, partName in ipairs(requiredParts) do
        local count = exports.ox_inventory:Search(source, 'count', partName)
        if not count or count < 1 then
            return false
        end
    end
    return true
end

---@param source number
---@param requiredParts table
local function removeRequiredParts(source, requiredParts)
    for _, partName in ipairs(requiredParts) do
        exports.ox_inventory:RemoveItem(source, partName, 1)
    end
end

---@param vehicle number
---@param data table
function EngineSwap.RestoreStateBag(vehicle, data)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    Entity(vehicle).state:set('engineData', {
        engineId = data.engine_id,
        wear = data.wear or 0,
        temperature = data.temperature or 20,
        totalKm = data.total_km or 0
    }, true)
end

lib.callback.register('mechanic:server:getEngineData', function(source, plate)
    local Player = Framework.GetPlayer(source)
    if not Player then return nil end
    if not Validation.IsMechanic(Player) then return nil end
    if not Validation.CheckRateLimit(source, 'engine_data', Config.Security.rateLimits.engineSwapMs) then return nil end
    if type(plate) ~= 'string' or #plate < 1 or #plate > 15 then return nil end
    return EngineSwap.GetData(plate)
end)

lib.callback.register('mechanic:server:getEngineCompatibility', function(source, netId, engineId)
    local Player = Framework.GetPlayer(source)
    if not Player then return nil end
    if not Validation.IsMechanic(Player) then return nil end

    local engineConfig = getEngineConfig(engineId)
    if not engineConfig then return nil end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle then return nil end

    local defaults = getVehicleDefaults(vehicle)
    local defaultEngine = Config.Engines[defaults.engine]
    if not defaultEngine then return nil end

    local drivetrainOk = false
    for _, dt in ipairs(engineConfig.drivetrainCompat) do
        if dt == defaults.drivetrain then
            drivetrainOk = true
            break
        end
    end

    local hasParts = hasRequiredParts(source, engineConfig.requiredParts)

    return {
        drivetrainCompatible = drivetrainOk,
        hasParts = hasParts,
        missingParts = not hasParts and engineConfig.requiredParts or nil,
        defaultEngine = defaults.engine,
        defaultDrivetrain = defaults.drivetrain,
        defaultHp = defaultEngine.hp,
        defaultTorque = defaultEngine.torque
    }
end)

lib.callback.register('mechanic:server:installEngine', function(source, netId, engineId)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'engine_swap', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'engine_swap', Config.Security.rateLimits.engineSwapMs) then
        Validation.LogDenied(src, 'engine_swap', 'rate_limited')
        return false
    end

    local engineConfig = getEngineConfig(engineId)
    if not engineConfig then
        Validation.LogDenied(src, 'engine_swap', 'invalid_engine_id')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.EngineSwap.maxDistance) then
        Validation.LogDenied(src, 'engine_swap', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'engine_swap', 'vehicle_unowned')
        return false
    end

    local defaults = getVehicleDefaults(vehicle)
    local drivetrainOk = false
    for _, dt in ipairs(engineConfig.drivetrainCompat) do
        if dt == defaults.drivetrain then
            drivetrainOk = true
            break
        end
    end

    if not drivetrainOk then
        Validation.LogDenied(src, 'engine_swap', 'drivetrain_incompatible')
        return false
    end

    if not hasRequiredParts(src, engineConfig.requiredParts) then
        Validation.LogDenied(src, 'engine_swap', 'missing_parts')
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, engineConfig.price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('engine_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local existingEngine = EngineSwap.GetData(plate)
    if existingEngine then
        local oldConfig = getEngineConfig(existingEngine.engine_id)
        if oldConfig then
            local metadata = { wear = existingEngine.wear }
            exports.ox_inventory:AddItem(src, existingEngine.engine_id, 1, metadata)
        end
    end

    removeRequiredParts(src, engineConfig.requiredParts)

    local citizenid = Player.PlayerData.citizenid
    EngineSwap.Install(plate, engineId, citizenid)

    Entity(vehicle).state:set('engineData', {
        engineId = engineId,
        wear = 0.00,
        temperature = 20.0,
        totalKm = 0.00
    }, true)

    return true
end)

lib.callback.register('mechanic:server:removeEngine', function(source, netId)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'engine_remove', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'engine_remove', Config.Security.rateLimits.engineSwapMs) then
        Validation.LogDenied(src, 'engine_remove', 'rate_limited')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.EngineSwap.maxDistance) then
        Validation.LogDenied(src, 'engine_remove', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local existingEngine = EngineSwap.GetData(plate)
    if not existingEngine then
        return false
    end

    local oldConfig = getEngineConfig(existingEngine.engine_id)
    if oldConfig then
        local metadata = { wear = existingEngine.wear }
        exports.ox_inventory:AddItem(src, existingEngine.engine_id, 1, metadata)
    end

    EngineSwap.Remove(plate)

    Entity(vehicle).state:set('engineData', nil, true)

    return true
end)

RegisterNetEvent('mechanic:server:syncEngineData', function(plate, wear, temperature, totalKm)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return end

    if not Validation.CheckRateLimit(src, 'engine_sync', Config.Security.rateLimits.engineSyncMs) then return end

    if type(plate) ~= 'string' or #plate < 1 or #plate > 15 then return end

    local clampedWear = Validation.ClampNumber(tonumber(wear), 0, 100, 0)
    local clampedTemp = Validation.ClampNumber(tonumber(temperature), 20, 120, 20)
    local clampedKm = Validation.ClampNumber(tonumber(totalKm), 0, 999999, 0)

    EngineSwap.SyncData(plate, clampedWear, clampedTemp, clampedKm)
end)

lib.callback.register('mechanic:server:loadEngineStateBag', function(source, netId)
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle then return false end
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate or plate == '' then return false end
    local data = EngineSwap.GetData(plate)
    if not data then return false end
    EngineSwap.RestoreStateBag(vehicle, data)
    return true
end)

return EngineSwap

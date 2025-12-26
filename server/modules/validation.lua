local Validation = {}
local Framework = require 'shared.framework'

-- TODO(PR-MERGE-ID): update with the actual PR identifier before merge to avoid conflicts.
local rateLimits = {}
local allowedProps = {
    plate = true,
    plateIndex = true,
    bodyHealth = true,
    engineHealth = true,
    fuelLevel = true,
    dirtLevel = true,
    color1 = true,
    color2 = true,
    pearlescentColor = true,
    wheelColor = true,
    wheels = true,
    windowTint = true,
    neonEnabled = true,
    neonColor = true,
    extras = true,
    tyreSmokeColor = true,
    modEngine = true,
    modBrakes = true,
    modTransmission = true,
    modSuspension = true,
    modTurbo = true,
    modArmor = true,
    modFrontWheels = true,
    modBackWheels = true,
    modHorns = true,
    modPlateHolder = true,
    modVanityPlate = true,
    modTrimA = true,
    modOrnaments = true,
    modDashboard = true,
    modDial = true,
    modDoorSpeaker = true,
    modSeats = true,
    modSteeringWheel = true,
    modShifterLeavers = true,
    modAPlate = true,
    modSpeakers = true,
    modTrunk = true,
    modHydrolic = true,
    modEngineBlock = true,
    modAirFilter = true,
    modStruts = true,
    modArchCover = true,
    modAerials = true,
    modTrimB = true,
    modTank = true,
    modWindows = true,
    modLivery = true,
    modRoof = true
}

local function isSafeKey(key)
    if type(key) ~= 'string' then return false end
    return allowedProps[key] or key:match('^mod%u')
end

local function sanitizeTable(value, depth)
    if type(value) ~= 'table' then return nil end
    if depth > 2 then return nil end

    local sanitized = {}
    local count = 0

    for k, v in pairs(value) do
        count = count + 1
        if count > 64 then
            return nil
        end

        local vType = type(v)
        if vType == 'number' or vType == 'boolean' or vType == 'string' then
            sanitized[k] = v
        elseif vType == 'table' then
            local nested = sanitizeTable(v, depth + 1)
            if nested then
                sanitized[k] = nested
            end
        end
    end

    return sanitized
end

function Validation.ClampNumber(value, minValue, maxValue, fallback)
    if type(value) ~= 'number' then
        return fallback
    end
    if minValue and value < minValue then
        return minValue
    end
    if maxValue and value > maxValue then
        return maxValue
    end
    return value
end

function Validation.IsValidCoords(coords)
    if type(coords) == 'vector3' or type(coords) == 'vector4' then
        return true
    end
    if type(coords) ~= 'table' then return false end
    return type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number'
end

function Validation.NormalizeCoords(coords)
    if type(coords) == 'vector3' then
        return coords
    end
    if type(coords) == 'vector4' then
        return vec3(coords.x, coords.y, coords.z)
    end
    if type(coords) ~= 'table' then return nil end
    if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
        return nil
    end
    return vec3(coords.x, coords.y, coords.z)
end

function Validation.CheckRateLimit(source, key, intervalMs)
    if not source or not key or type(intervalMs) ~= 'number' then
        return false
    end

    rateLimits[source] = rateLimits[source] or {}
    local now = GetGameTimer()
    local last = rateLimits[source][key] or 0
    if now - last < intervalMs then
        return false
    end
    rateLimits[source][key] = now
    return true
end

function Validation.IsNumberInRange(value, minValue, maxValue)
    if type(value) ~= 'number' then return false end
    if minValue and value < minValue then return false end
    if maxValue and value > maxValue then return false end
    return true
end

function Validation.IsMechanic(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == Config.JobName
end

function Validation.IsAdmin(source)
    return Framework.HasPermission(source, 'admin')
end

function Validation.GetVehicleByNetId(netId)
    if type(netId) ~= 'number' then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and DoesEntityExist(vehicle) then
        return vehicle
    end
    return nil
end

function Validation.GetVehicleByPlate(plate)
    if not plate or plate == '' then return nil end
    for _, vehicle in ipairs(GetAllVehicles()) do
        if GetVehicleNumberPlateText(vehicle) == plate then
            return vehicle
        end
    end
    return nil
end

function Validation.IsPlayerNearEntity(source, entity, maxDistance)
    if not entity or not DoesEntityExist(entity) then return false end
    local ped = GetPlayerPed(source)
    if not ped or not DoesEntityExist(ped) then return false end
    local playerCoords = GetEntityCoords(ped)
    local entityCoords = GetEntityCoords(entity)
    return #(playerCoords - entityCoords) <= (maxDistance or 10.0)
end

function Validation.IsVehicleOwned(plate)
    local result = MySQL.query.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate})
    if result and result[1] then
        return true, result[1].citizenid
    end
    return false, nil
end

function Validation.IsVehicleOwnedBy(plate, citizenid)
    if not citizenid then return false end
    local result = MySQL.query.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate})
    return result and result[1] and result[1].citizenid == citizenid
end

function Validation.SanitizeProps(props)
    if type(props) ~= 'table' then return nil end
    local sanitized = {}

    for key, value in pairs(props) do
        if isSafeKey(key) then
            local valueType = type(value)
            if valueType == 'number' or valueType == 'boolean' or valueType == 'string' then
                sanitized[key] = value
            elseif valueType == 'table' then
                local nested = sanitizeTable(value, 1)
                if nested then
                    sanitized[key] = nested
                end
            end
        end
    end

    if next(sanitized) == nil then
        return nil
    end

    return sanitized
end

function Validation.NormalizeFluidData(data)
    if type(data) ~= 'table' then return nil end

    return {
        oilLevel = Validation.ClampNumber(tonumber(data.oilLevel), 0, 100, 100),
        coolantLevel = Validation.ClampNumber(tonumber(data.coolantLevel), 0, 100, 100),
        brakeFluidLevel = Validation.ClampNumber(tonumber(data.brakeFluidLevel), 0, 100, 100),
        transmissionFluidLevel = Validation.ClampNumber(tonumber(data.transmissionFluidLevel), 0, 100, 100),
        powerSteeringLevel = Validation.ClampNumber(tonumber(data.powerSteeringLevel), 0, 100, 100),
        tireWear = Validation.ClampNumber(tonumber(data.tireWear), 0, 100, 0),
        batteryLevel = Validation.ClampNumber(tonumber(data.batteryLevel), 0, 100, 100),
        gearBoxHealth = Validation.ClampNumber(tonumber(data.gearBoxHealth), 0, 100, 100)
    }
end

function Validation.NormalizeImpactData(data)
    if type(data) ~= 'table' then return nil end

    local side = type(data.side) == 'string' and data.side or ''
    if #side > 32 then
        side = ''
    end

    return {
        side = side,
        severity = Validation.ClampNumber(tonumber(data.severity), 0, 10, 0),
        wheelDamage = data.wheelDamage == true
    }
end

function Validation.CalculatePerformanceModPrice(modType, level)
    local config = Config.Tuning and Config.Tuning.performanceMods and Config.Tuning.performanceMods[modType]
    if not config then return nil end
    if not Validation.IsNumberInRange(level, 0, config.maxLevel) then return nil end
    return config.basePrice * (level + 1)
end

function Validation.CalculateVisualModPrice(modType, modIndex)
    local config = Config.Tuning and Config.Tuning.visualMods and Config.Tuning.visualMods[modType]
    if not config then return nil end
    if type(modIndex) ~= 'number' or modIndex < -1 then
        return nil
    end
    -- TODO: validate modIndex against vehicle-specific mod count.
    if modIndex == -1 then
        return 0
    end
    return config.basePrice + (modIndex * 500)
end

function Validation.GetMaxPartUnitPrice()
    local maxPrice = 0
    for _, item in pairs(Config.MaintenanceItems or {}) do
        local price = math.floor((item.price or 0) * (Config.Economy.partMarkup or 1))
        if price > maxPrice then
            maxPrice = price
        end
    end
    for _, part in pairs(Config.VehicleParts or {}) do
        local price = math.floor((part.price or 0) * (Config.Economy.partMarkup or 1))
        if price > maxPrice then
            maxPrice = price
        end
    end
    if maxPrice == 0 then
        maxPrice = Config.Billing.parts.fallbackMaxUnitPrice
    end
    return maxPrice
end

function Validation.NormalizeInvoice(invoice)
    if type(invoice) ~= 'table' then return nil end
    if type(invoice.targetPlayer) ~= 'number' then return nil end
    if type(invoice.items) ~= 'table' then return nil end

    local normalized = {
        items = {},
        labor = 0,
        parts = 0,
        total = 0,
        targetPlayer = invoice.targetPlayer
    }

    local maxPartUnitPrice = Validation.GetMaxPartUnitPrice()
    local laborConfig = Config.Billing.labor
    local partsConfig = Config.Billing.parts

    for _, item in ipairs(invoice.items) do
        if type(item) == 'table' and type(item.type) == 'string' and type(item.label) == 'string' then
            if item.type == 'labor' then
                local hours = tonumber(item.quantity)
                local rate = tonumber(item.price)
                if Validation.IsNumberInRange(hours, laborConfig.minHours, laborConfig.maxHours)
                    and Validation.IsNumberInRange(rate, laborConfig.minRate, laborConfig.maxRate) then
                    local total = hours * rate
                    table.insert(normalized.items, {
                        type = 'labor',
                        label = item.label,
                        quantity = hours,
                        price = rate,
                        total = total
                    })
                    normalized.labor = normalized.labor + total
                end
            elseif item.type == 'part' then
                local quantity = tonumber(item.quantity)
                local price = tonumber(item.price)
                if Validation.IsNumberInRange(quantity, partsConfig.minQuantity, partsConfig.maxQuantity)
                    and Validation.IsNumberInRange(price, 1, maxPartUnitPrice) then
                    local total = quantity * price
                    table.insert(normalized.items, {
                        type = 'part',
                        label = item.label,
                        quantity = quantity,
                        price = price,
                        total = total
                    })
                    normalized.parts = normalized.parts + total
                end
            end
        end
    end

    normalized.total = normalized.labor + normalized.parts

    if normalized.total <= 0 then
        return nil
    end

    if Config.Billing.maxInvoiceTotal and normalized.total > Config.Billing.maxInvoiceTotal then
        return nil
    end

    return normalized
end

return Validation

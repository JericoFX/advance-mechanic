local Validation = {}

function Validation.IsNumberInRange(value, minValue, maxValue)
    if type(value) ~= 'number' then return false end
    if minValue and value < minValue then return false end
    if maxValue and value > maxValue then return false end
    return true
end

function Validation.IsMechanic(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == Config.JobName
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
    -- TODO: enforce a whitelist of allowed properties.
    return props
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

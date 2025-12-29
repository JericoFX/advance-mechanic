local Vehicles = {}
local Database = require 'server.modules.database'
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

local function canAccessVehicle(source, vehicle, plate, requireMechanic)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end

    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if not Validation.IsPlayerNearEntity(source, vehicle, 10.0) then return false end

    if requireMechanic and not Validation.IsMechanic(Player) and not Validation.IsAdmin(source) then
        return false
    end

    local isOwner = Validation.IsVehicleOwnedBy(plate, Player.PlayerData.citizenid)
    if not isOwner and not Validation.IsMechanic(Player) and not Validation.IsAdmin(source) then
        return false
    end

    return true
end

-- Get vehicle inspection data
function Vehicles.GetInspectionData(plate)
    local query = 'SELECT inspection_data FROM player_vehicles WHERE plate = ?'
    local result = MySQL.query.await(query, {plate})
    
    if result and result[1] and result[1].inspection_data then
        return json.decode(result[1].inspection_data)
    end
    
    -- Return default inspection data
    local defaultData = {}
    for name, checkpoint in pairs(Config.Inspection.checkPoints) do
        defaultData[name] = {
            health = 100,
            lastChecked = os.time()
        }
    end
    return defaultData
end

-- Get vehicle fluid data
function Vehicles.GetFluidData(plate)
    local query = 'SELECT fluid_data FROM player_vehicles WHERE plate = ?'
    local result = MySQL.query.await(query, {plate})
    
    if result and result[1] and result[1].fluid_data then
        local fluidData = json.decode(result[1].fluid_data)
        return {
            oilLevel = fluidData.oilLevel or 100,
            coolantLevel = fluidData.coolantLevel or 100,
            brakeFluidLevel = fluidData.brakeFluidLevel or 100,
            transmissionFluidLevel = fluidData.transmissionFluidLevel or 100,
            powerSteeringLevel = fluidData.powerSteeringLevel or 100,
            tireWear = fluidData.tireWear or 0,
            batteryLevel = fluidData.batteryLevel or 100,
            gearBoxHealth = fluidData.gearBoxHealth or 100,
            lastUpdate = fluidData.lastUpdate or os.time(),
            lastUpdated = fluidData.lastUpdated or fluidData.lastUpdate or os.time()
        }
    end
    
    -- Return default fluid data
    return {
        oilLevel = 100,
        coolantLevel = 100,
        brakeFluidLevel = 100,
        transmissionFluidLevel = 100,
        powerSteeringLevel = 100,
        tireWear = 0,
        batteryLevel = 100,
        gearBoxHealth = 100,
        lastUpdate = os.time(),
        lastUpdated = os.time()
    }
end

-- Update vehicle fluid data
function Vehicles.UpdateFluidData(plate, data)
    local query = 'UPDATE player_vehicles SET fluid_data = ? WHERE plate = ?'
    data.lastUpdate = os.time()
    data.lastUpdated = data.lastUpdate
    return MySQL.update.await(query, {json.encode(data), plate}) > 0
end

-- Update vehicle inspection data
function Vehicles.UpdateInspectionData(plate, data)
    local query = 'UPDATE player_vehicles SET inspection_data = ? WHERE plate = ?'
    return MySQL.update.await(query, {json.encode(data), plate}) > 0
end

-- Check if vehicle is owned
function Vehicles.IsOwned(plate)
    local query = 'SELECT citizenid FROM player_vehicles WHERE plate = ?'
    local result = MySQL.query.await(query, {plate})
    return result and result[1] ~= nil
end

-- Update vehicle color using ox_lib
function Vehicles.UpdateColor(source, plate, colorType, color)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    -- Check if player owns the vehicle
    local query = 'SELECT citizenid, props FROM player_vehicles WHERE plate = ?'
    local result = MySQL.query.await(query, {plate})
    
    if not result or not result[1] or result[1].citizenid ~= Player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('not_vehicle_owner'),
            type = 'error'
        })
        return false
    end
    
    -- Get current properties
    local props = result[1].props and json.decode(result[1].props) or {}
    
    -- Update color in properties
    if colorType == 'primary' then
        props.color1 = color
    elseif colorType == 'secondary' then
        props.color2 = color
    end
    
    -- Save to database
    if Database.UpdateVehicleProperties(plate, props) then
        -- Apply to vehicle if it exists
        local vehicle = Vehicles.GetVehicleByPlate(plate)
        if vehicle and DoesEntityExist(vehicle) then
            TriggerClientEvent('mechanic:client:syncVehicleProperties', -1, NetworkGetNetworkIdFromEntity(vehicle), props)
        end
        
        return true
    end
    
    return false
end

-- Get vehicle by plate
function Vehicles.GetVehicleByPlate(plate)
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        if GetVehicleNumberPlateText(vehicle) == plate then
            return vehicle
        end
    end
    return nil
end

-- Handle vehicle damage
function Vehicles.ProcessDamage(plate, impactData)
    local inspectionData = Vehicles.GetInspectionData(plate)
    
    -- Apply damage based on impact
    if impactData.side:find('front') then
        inspectionData.engine.health = math.max(0, (inspectionData.engine.health or 100) - (impactData.severity * 10))
        inspectionData.radiator.health = math.max(0, (inspectionData.radiator.health or 100) - (impactData.severity * 5))
    elseif impactData.side:find('rear') then
        inspectionData.transmission.health = math.max(0, (inspectionData.transmission.health or 100) - (impactData.severity * 8))
    end
    
    -- Wheel damage
    if impactData.wheelDamage then
        inspectionData.suspension.health = math.max(0, (inspectionData.suspension.health or 100) - 20)
        inspectionData.tires.health = math.max(0, (inspectionData.tires.health or 100) - 30)
    end
    
    -- Save updated data
    Vehicles.UpdateInspectionData(plate, inspectionData)
    
    -- Notify nearby mechanics
    local coords = impactData.coords
    if coords then
        for _, playerId in ipairs(GetPlayers()) do
            local Player = Framework.GetPlayer(tonumber(playerId))
            if Player and Player.PlayerData.job.name == Config.JobName then
                local ped = GetPlayerPed(tonumber(playerId))
                local playerCoords = GetEntityCoords(ped)
                
                if #(playerCoords - coords) < 100.0 then
                    TriggerClientEvent('ox_lib:notify', tonumber(playerId), {
                        title = locale('vehicle_damaged_nearby'),
                        description = locale('vehicle_needs_repair'),
                        type = 'info'
                    })
                end
            end
        end
    end
end

-- Repair vehicle part
function Vehicles.RepairPart(source, plate, part, amount)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    -- Check if mechanic
    if not Validation.IsMechanic(Player) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('not_mechanic'),
            type = 'error'
        })
        return false
    end
    
    -- Get inspection data
    local inspectionData = Vehicles.GetInspectionData(plate)
    
    if inspectionData[part] then
        inspectionData[part].health = math.min(100, (inspectionData[part].health or 0) + amount)
        inspectionData[part].lastRepaired = os.time()
        inspectionData[part].repairedBy = Player.PlayerData.citizenid
        
        -- Save data
        if Vehicles.UpdateInspectionData(plate, inspectionData) then
            -- Log repair
            print(string.format('[Mechanic] %s repaired %s on vehicle %s', Player.PlayerData.name, part, plate))
            
            return true
        end
    end
    
    return false
end

-- Purchase vehicle part
function Vehicles.PurchasePart(source, partId, quantity, totalPrice)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    local partData = Config.VehicleParts[partId]
    if not partData then return false end
    
    if not Validation.IsNumberInRange(quantity, 1, Config.Billing.parts.maxQuantity) then
        return false
    end

    local unitPrice = math.floor(partData.price * Config.Economy.partMarkup)
    local calculatedTotal = unitPrice * quantity

    -- Check money
    local money = Config.Economy.payWithCash and Player.PlayerData.money.cash or Player.PlayerData.money.bank
    if money < calculatedTotal then
        return false
    end
    
    -- Remove money
    if Config.Economy.payWithCash then
        Player.Functions.RemoveMoney('cash', calculatedTotal)
    else
        Player.Functions.RemoveMoney('bank', calculatedTotal)
    end
    
    -- Give items
    if exports.ox_inventory:AddItem(source, partData.item, quantity) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('purchase_successful'),
            description = locale('purchased_parts', quantity, partData.label),
            type = 'success'
        })
        return true
    end
    
    -- Refund if failed
    if Config.Economy.payWithCash then
        Player.Functions.AddMoney('cash', calculatedTotal)
    else
        Player.Functions.AddMoney('bank', calculatedTotal)
    end
    
    return false
end

-- Callbacks
lib.callback.register('mechanic:server:isVehicleOwned', function(source, plate)
    return Vehicles.IsOwned(plate)
end)

lib.callback.register('mechanic:server:getVehicleInspection', function(source, plate)
    local Player = Framework.GetPlayer(source)
    if not Player or type(plate) ~= 'string' or #plate < 1 or #plate > 12 then return nil end

    if not Validation.CheckRateLimit(source, 'vehicle_inspection', Config.Security.rateLimits.vehicleInspectionMs) then
        return nil
    end

    local vehicle = Vehicles.GetVehicleByPlate(plate)
    if vehicle then
        if not canAccessVehicle(source, vehicle, plate, false) then
            return nil
        end
    else
        local isOwner = Validation.IsVehicleOwnedBy(plate, Player.PlayerData.citizenid)
        if not isOwner and not Validation.IsMechanic(Player) and not Validation.IsAdmin(source) then
            return nil
        end
    end

    return Vehicles.GetInspectionData(plate)
end)

lib.callback.register('mechanic:server:purchasePart', function(source, partId, quantity, totalPrice)
    return Vehicles.PurchasePart(source, partId, quantity, totalPrice)
end)

lib.callback.register('mechanic:server:getVehicleFluidData', function(source, plate)
    local Player = Framework.GetPlayer(source)
    if not Player or type(plate) ~= 'string' or #plate < 1 or #plate > 12 then return nil end

    if not Validation.CheckRateLimit(source, 'vehicle_fluid', Config.Security.rateLimits.vehicleFluidMs) then
        return nil
    end

    local vehicle = Vehicles.GetVehicleByPlate(plate)
    if vehicle then
        if not canAccessVehicle(source, vehicle, plate, false) then
            return nil
        end
    else
        local isOwner = Validation.IsVehicleOwnedBy(plate, Player.PlayerData.citizenid)
        if not isOwner and not Validation.IsMechanic(Player) and not Validation.IsAdmin(source) then
            return nil
        end
    end

    return Vehicles.GetFluidData(plate)
end)

lib.callback.register('mechanic:server:updateVehicleFluidData', function(source, plate, fluidData)
    local Player = Framework.GetPlayer(source)
    if not Player or type(plate) ~= 'string' then return false end

    local vehicle = Vehicles.GetVehicleByPlate(plate)
    if not vehicle then return false end

    if not Validation.CheckRateLimit(source, 'fluid_update', Config.Security.rateLimits.fluidUpdateMs) then
        return false
    end

    if not canAccessVehicle(source, vehicle, plate, false) then
        return false
    end

    local normalized = Validation.NormalizeFluidData(fluidData)
    if not normalized then return false end

    return Vehicles.UpdateFluidData(plate, normalized)
end)

-- Events
RegisterNetEvent('mechanic:server:updateVehicleColor', function(plate, colorType, color)
    if type(plate) ~= 'string' or #plate < 1 or #plate > 12 then return end
    if colorType ~= 'primary' and colorType ~= 'secondary' then return end

    local numericColor = tonumber(color)
    if not Validation.IsNumberInRange(numericColor, 0, 160) then return end

    if not Validation.CheckRateLimit(source, 'vehicle_color', Config.Security.rateLimits.vehicleColorMs) then
        return
    end

    local vehicle = Vehicles.GetVehicleByPlate(plate)
    if vehicle and not Validation.IsPlayerNearEntity(source, vehicle, 10.0) then
        return
    end

    Vehicles.UpdateColor(source, plate, colorType, numericColor)
end)

RegisterNetEvent('mechanic:server:vehicleDamaged', function(plate, impactData)
    if type(plate) ~= 'string' then return end

    if not Validation.CheckRateLimit(source, 'vehicle_damage', Config.Security.rateLimits.vehicleDamageMs) then
        return
    end

    local vehicle = Vehicles.GetVehicleByPlate(plate)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if not Validation.IsPlayerNearEntity(source, vehicle, 15.0) then return end

    local ped = GetPlayerPed(source)
    if GetVehiclePedIsIn(ped, false) ~= vehicle and NetworkGetEntityOwner(vehicle) ~= source then
        return
    end

    local normalizedImpact = Validation.NormalizeImpactData(impactData)
    if not normalizedImpact then return end

    -- Add source coords for nearby notification
    normalizedImpact.coords = GetEntityCoords(ped)
    
    MySQL.update('UPDATE player_vehicles SET damage_data = ? WHERE plate = ?', {
        json.encode(normalizedImpact),
        plate
    })

    Vehicles.ProcessDamage(plate, normalizedImpact)
end)

RegisterNetEvent('mechanic:server:repairVehiclePart', function(plate, part, amount)
    if type(plate) ~= 'string' then return end
    if type(part) ~= 'string' or not Config.Inspection.checkPoints[part] then return end

    local numericAmount = tonumber(amount)
    if not Validation.IsNumberInRange(numericAmount, 1, 100) then return end

    local vehicle = Vehicles.GetVehicleByPlate(plate)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, 10.0) then return end

    if Vehicles.RepairPart(source, plate, part, numericAmount) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('repair_successful'),
            type = 'success'
        })
    end
end)

-- Sync vehicle properties to clients
RegisterNetEvent('mechanic:server:syncVehicleProperties', function(netId, props)
    local Player = Framework.GetPlayer(source)
    if not Player then return end

    if not Validation.CheckRateLimit(source, 'vehicle_props', Config.Security.rateLimits.vehiclePropsMs) then
        return
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not canAccessVehicle(source, vehicle, plate, false) then
        return
    end

    local sanitizedProps = Validation.SanitizeProps(props)
    if not sanitizedProps then return end

    TriggerClientEvent('mechanic:client:syncVehicleProperties', -1, netId, sanitizedProps)
end)

-- Sincronización de niveles de fluidos
RegisterNetEvent('mechanic:server:syncFluidLevels', function(plate, fluidData)
    local src = source
    
    -- Validar datos
    if not plate or not fluidData then return end
    
    -- Validar que el jugador esté cerca del vehículo
    local ped = GetPlayerPed(src)
    local vehicle = Vehicles.GetVehicleByPlate(plate)
    
    if vehicle and DoesEntityExist(vehicle) then
        local Player = Framework.GetPlayer(src)
        if not Player then return end

        if not Validation.CheckRateLimit(src, 'fluid_sync', Config.Security.rateLimits.fluidSyncMs) then
            return
        end

        local isOwner = Validation.IsVehicleOwnedBy(plate, Player.PlayerData.citizenid)
        if not isOwner and not Validation.IsMechanic(Player) and not Validation.IsAdmin(src) then
            return
        end

        local vehicleCoords = GetEntityCoords(vehicle)
        local playerCoords = GetEntityCoords(ped)
        
        -- Solo permitir sincronización si está cerca del vehículo
        if #(vehicleCoords - playerCoords) < 10.0 then
            local normalized = Validation.NormalizeFluidData(fluidData)
            if not normalized then return end
            
            -- Actualizar en base de datos
            Vehicles.UpdateFluidData(plate, normalized)
            
            -- Log para debugging
            if Config.Debug then
                print(string.format('[Mechanic] Player %s synced fluid levels for vehicle %s', src, plate))
            end
        end
    end
end)

return Vehicles

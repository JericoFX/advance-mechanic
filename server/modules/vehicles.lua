local Vehicles = {}
local Database = require 'server.modules.database'
local Framework = require 'shared.framework'

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
        return json.decode(result[1].fluid_data)
    end
    
    -- Return default fluid data
    return {
        oilLevel = 100,
        coolantLevel = 100,
        brakeFluidLevel = 100,
        transmissionFluidLevel = 100,
        powerSteeringLevel = 100,
        lastUpdated = os.time()
    }
end

-- Update vehicle fluid data
function Vehicles.UpdateFluidData(plate, data)
    local query = 'UPDATE player_vehicles SET fluid_data = ? WHERE plate = ?'
    data.lastUpdated = os.time()
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
    if Player.PlayerData.job.name ~= Config.JobName then
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
    
    -- Check money
    local money = Config.Economy.payWithCash and Player.PlayerData.money.cash or Player.PlayerData.money.bank
    if money < totalPrice then
        return false
    end
    
    -- Remove money
    if Config.Economy.payWithCash then
        Player.Functions.RemoveMoney('cash', totalPrice)
    else
        Player.Functions.RemoveMoney('bank', totalPrice)
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
        Player.Functions.AddMoney('cash', totalPrice)
    else
        Player.Functions.AddMoney('bank', totalPrice)
    end
    
    return false
end

-- Callbacks
lib.callback.register('mechanic:server:isVehicleOwned', function(source, plate)
    return Vehicles.IsOwned(plate)
end)

lib.callback.register('mechanic:server:getVehicleInspection', function(source, plate)
    return Vehicles.GetInspectionData(plate)
end)

lib.callback.register('mechanic:server:purchasePart', function(source, partId, quantity, totalPrice)
    return Vehicles.PurchasePart(source, partId, quantity, totalPrice)
end)

lib.callback.register('mechanic:server:getVehicleFluidData', function(source, plate)
    return Vehicles.GetFluidData(plate)
end)

lib.callback.register('mechanic:server:updateVehicleFluidData', function(source, plate, fluidData)
    return Vehicles.UpdateFluidData(plate, fluidData)
end)

-- Events
RegisterNetEvent('mechanic:server:updateVehicleColor', function(plate, colorType, color)
    Vehicles.UpdateColor(source, plate, colorType, color)
end)

RegisterNetEvent('mechanic:server:vehicleDamaged', function(plate, impactData)
    -- Add source coords for nearby notification
    local ped = GetPlayerPed(source)
    impactData.coords = GetEntityCoords(ped)
    
    Vehicles.ProcessDamage(plate, impactData)
end)

RegisterNetEvent('mechanic:server:repairVehiclePart', function(plate, part, amount)
    if Vehicles.RepairPart(source, plate, part, amount) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('repair_successful'),
            type = 'success'
        })
    end
end)

-- Sync vehicle properties to clients
RegisterNetEvent('mechanic:server:syncVehicleProperties', function(netId, props)
    TriggerClientEvent('mechanic:client:syncVehicleProperties', -1, netId, props)
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
        local vehicleCoords = GetEntityCoords(vehicle)
        local playerCoords = GetEntityCoords(ped)
        
        -- Solo permitir sincronización si está cerca del vehículo
        if #(vehicleCoords - playerCoords) < 10.0 then
            -- Validar niveles de fluidos (anti-cheat)
            fluidData.oilLevel = math.max(0, math.min(100, fluidData.oilLevel or 100))
            fluidData.coolantLevel = math.max(0, math.min(100, fluidData.coolantLevel or 100))
            fluidData.brakeFluidLevel = math.max(0, math.min(100, fluidData.brakeFluidLevel or 100))
            fluidData.transmissionFluidLevel = math.max(0, math.min(100, fluidData.transmissionFluidLevel or 100))
            fluidData.powerSteeringLevel = math.max(0, math.min(100, fluidData.powerSteeringLevel or 100))
            
            -- Actualizar en base de datos
            Vehicles.UpdateFluidData(plate, fluidData)
            
            -- Log para debugging
            if Config.Debug then
                print(string.format('[Mechanic] Player %s synced fluid levels for vehicle %s', src, plate))
            end
        end
    end
end)

return Vehicles

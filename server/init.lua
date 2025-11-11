-- Initialize QBCore
QBCore = exports[Config.Framework.resourceName]:GetCoreObject()

-- Load modules
local Database = require 'server.modules.database'
local Shops = require 'server.modules.shops'
local Vehicles = require 'server.modules.vehicles'
local Missions = require 'server.modules.missions'
local Billing = require 'server.modules.billing'
local Tuning = require 'server.modules.tuning'

-- Initialize database tables on resource start
CreateThread(function()
    -- Create mechanic_shops table if not exists
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mechanic_shops` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) NOT NULL,
            `owner` varchar(50) DEFAULT NULL,
            `price` int(11) NOT NULL DEFAULT 100000,
            `zones` longtext NOT NULL,
            `lifts` longtext NOT NULL,
            `vehicleSpawns` longtext NOT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Create mechanic_employees table if not exists
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mechanic_employees` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `shop_id` int(11) NOT NULL,
            `citizenid` varchar(50) NOT NULL,
            `grade` int(11) NOT NULL DEFAULT 0,
            `hired_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `shop_id` (`shop_id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Add inspection_data and props columns to player_vehicles if not exists
    MySQL.query([[
        ALTER TABLE `player_vehicles` 
        ADD COLUMN IF NOT EXISTS `inspection_data` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `props` longtext DEFAULT NULL;
    ]])
    
    print('[Advanced Mechanic] Database tables initialized')
end)

-- Admin commands
lib.addCommand('setmechanic', {
    help = 'Set a player as mechanic',
    params = {
        {name = 'target', type = 'playerId', help = 'Target player ID'},
        {name = 'grade', type = 'number', help = 'Job grade (0-4)', optional = true}
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    local targetPlayer = QBCore.Functions.GetPlayer(args.target)
    if targetPlayer then
        targetPlayer.Functions.SetJob(Config.JobName, args.grade or 0)
        TriggerClientEvent('ox_lib:notify', args.target, {
            title = 'Job Updated',
            description = 'You are now a mechanic',
            type = 'success'
        })
        
        if source > 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Success',
                description = 'Player set as mechanic',
                type = 'success'
            })
        end
    end
end)

-- Mechanic menu command
lib.addCommand('mechanicmenu', {
    help = 'Open mechanic menu',
    restricted = false
}, function(source, args, raw)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player and Player.PlayerData.job.name == Config.JobName then
        TriggerClientEvent('mechanic:client:openMenu', source)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You are not a mechanic',
            type = 'error'
        })
    end
end)

-- Create shop command
lib.addCommand('createshop', {
    help = 'Create a new mechanic shop',
    restricted = Config.ShopCreation.requiresAdmin and 'group.admin' or false
}, function(source, args, raw)
    TriggerClientEvent('mechanic:client:startShopCreation', source)
end)

-- Mechanic job check
QBCore.Functions.CreateCallback('mechanic:server:isPlayerMechanic', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        cb(Player.PlayerData.job.name == Config.JobName)
    else
        cb(false)
    end
end)

-- Vehicle spawn handler
RegisterNetEvent('mechanic:server:deleteVehicle', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end)

-- Add mechanic job if not exists
CreateThread(function()
    Wait(1000)
    
    -- Check if job exists
    local result = MySQL.query.await('SELECT * FROM jobs WHERE name = ?', {Config.JobName})
    
    if not result or #result == 0 then
        -- Create mechanic job
        MySQL.insert([[
            INSERT INTO jobs (name, label, grades) VALUES (?, ?, ?)
        ]], {
            Config.JobName,
            'Mechanic',
            json.encode({
                ['0'] = {name = 'Recruit', payment = 50},
                ['1'] = {name = 'Novice', payment = 75},
                ['2'] = {name = 'Experienced', payment = 100},
                ['3'] = {name = 'Expert', payment = 125},
                ['4'] = {name = 'Boss', payment = 150, isboss = true}
            })
        })
        
        print('[Advanced Mechanic] Mechanic job created')
    end
end)

-- Export functions
exports('getMechanicShops', function()
    return Shops.GetAll()
end)

exports('isVehicleOwned', function(plate)
    return Vehicles.IsOwned(plate)
end)

exports('getVehicleInspectionData', function(plate)
    return Vehicles.GetInspectionData(plate)
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Clean up any spawned vehicles
        print('[Advanced Mechanic] Resource stopped, cleaning up...')
    end
end)

-- Additional callbacks for new features
lib.callback.register('mechanic:server:getVehicleData', function(source, plate)
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
    
    if result and result[1] then
        local vehicleData = result[1]
        vehicleData.maintenanceHistory = json.decode(vehicleData.maintenance_history or '[]')
        vehicleData.inspectionData = json.decode(vehicleData.inspection_data or '{}')
        return vehicleData
    end
    
    return nil
end)

lib.callback.register('mechanic:server:repairVehicle', function(source, netId, cost)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return false end
    
    if Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    if Player.Functions.RemoveMoney('cash', cost) then
        return true
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

lib.callback.register('mechanic:server:purchasePart', function(source, item, quantity, totalPrice)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return false end
    
    if Player.Functions.RemoveMoney('cash', totalPrice) then
        exports.ox_inventory:AddItem(src, item, quantity)
        return true
    else
        return false
    end
end)

lib.callback.register('mechanic:server:generateDiagnosticReport', function(source, plate, diagnosticData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    -- Save diagnostic report to database
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local report = {
        date = timestamp,
        mechanic = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        data = diagnosticData
    }
    
    MySQL.update('UPDATE player_vehicles SET last_diagnostic = ? WHERE plate = ?', {
        json.encode(report),
        plate
    })
    
    return true
end)

-- Vehicle damage tracking
RegisterNetEvent('mechanic:server:vehicleDamaged', function(plate, damageData)
    local src = source
    
    -- Update vehicle damage in database
    MySQL.update('UPDATE player_vehicles SET damage_data = ? WHERE plate = ?', {
        json.encode(damageData),
        plate
    })
end)

-- Enhanced fluid and component data callback
lib.callback.register('mechanic:server:getVehicleFluidData', function(source, plate)
    local result = MySQL.query.await('SELECT fluid_data FROM player_vehicles WHERE plate = ?', {plate})
    
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
            gearBoxHealth = fluidData.gearBoxHealth or 100
        }
    end
    
    -- Return default values for new vehicles
    return {
        oilLevel = 100,
        coolantLevel = 100,
        brakeFluidLevel = 100,
        transmissionFluidLevel = 100,
        powerSteeringLevel = 100,
        tireWear = 0,
        batteryLevel = 100,
        gearBoxHealth = 100
    }
end)

-- Enhanced fluid sync event
RegisterNetEvent('mechanic:server:syncFluidLevels', function(plate, fluidData)
    local src = source
    
    -- Enhanced fluid data with new components
    local enhancedFluidData = {
        oilLevel = fluidData.oilLevel or 100,
        coolantLevel = fluidData.coolantLevel or 100,
        brakeFluidLevel = fluidData.brakeFluidLevel or 100,
        transmissionFluidLevel = fluidData.transmissionFluidLevel or 100,
        powerSteeringLevel = fluidData.powerSteeringLevel or 100,
        tireWear = fluidData.tireWear or 0,
        batteryLevel = fluidData.batteryLevel or 100,
        gearBoxHealth = fluidData.gearBoxHealth or 100,
        lastUpdate = os.time()
    }
    
    MySQL.update('UPDATE player_vehicles SET fluid_data = ? WHERE plate = ?', {
        json.encode(enhancedFluidData),
        plate
    })
end)

-- Repair component callback
lib.callback.register('mechanic:server:repairComponent', function(source, plate, component, cost)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    if Player.Functions.RemoveMoney('cash', cost) then
        -- Get current fluid data
        local result = MySQL.query.await('SELECT fluid_data FROM player_vehicles WHERE plate = ?', {plate})
        local fluidData = {}
        
        if result and result[1] and result[1].fluid_data then
            fluidData = json.decode(result[1].fluid_data)
        end
        
        -- Repair the specific component
        if component == 'tires' then
            fluidData.tireWear = 0
        elseif component == 'battery' then
            fluidData.batteryLevel = 100
        elseif component == 'gearbox' then
            fluidData.gearBoxHealth = 100
        elseif component == 'oil' then
            fluidData.oilLevel = 100
        elseif component == 'coolant' then
            fluidData.coolantLevel = 100
        elseif component == 'brake_fluid' then
            fluidData.brakeFluidLevel = 100
        elseif component == 'power_steering' then
            fluidData.powerSteeringLevel = 100
        end
        
        -- Update database
        MySQL.update('UPDATE player_vehicles SET fluid_data = ? WHERE plate = ?', {
            json.encode(fluidData),
            plate
        })
        
        return true
    end
    
    return false
end)

print('[Advanced Mechanic] Server initialized successfully')

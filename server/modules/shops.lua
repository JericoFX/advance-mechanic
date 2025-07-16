local Shops = {}
local Database = require 'server.modules.database'
local Business = require 'server.modules.business'
local QBCore = exports['qb-core']:GetCoreObject()
local shopCache = {}

-- Load all shops from database
function Shops.LoadAll()
    shopCache = Database.GetAllShops()
    -- Sync to all clients
    TriggerClientEvent('mechanic:client:shopsUpdated', -1, shopCache)
end

-- Get all shops
function Shops.GetAll()
    return shopCache
end

-- Get shop by ID
function Shops.GetById(shopId)
    for _, shop in ipairs(shopCache) do
        if shop.id == shopId then
            return shop
        end
    end
    return nil
end

-- Create new shop
function Shops.Create(data, source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    -- Check admin permissions
    if Config.ShopCreation.requiresAdmin and not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('no_permission'),
            type = 'error'
        })
        return false
    end
    
    local shopId = Database.CreateShop(data)
    if shopId then
        -- Reload shops
        Shops.LoadAll()
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_created'),
            description = locale('shop_created_desc', data.name),
            type = 'success'
        })
        
        return true
    end
    
    return false
end

-- Update shop owner
function Shops.UpdateOwner(shopId, citizenid)
    local query = 'UPDATE mechanic_shops SET owner = ? WHERE id = ?'
    if MySQL.update.await(query, {citizenid, shopId}) > 0 then
        Shops.LoadAll()
        return true
    end
    return false
end

-- Purchase shop
function Shops.Purchase(source, shopId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local shop = Shops.GetById(shopId)
    if not shop then return false end
    
    -- Check if shop is already owned
    if shop.owner then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_already_owned'),
            type = 'error'
        })
        return false
    end
    
    -- Check money
    local money = Config.Economy.payWithCash and Player.PlayerData.money.cash or Player.PlayerData.money.bank
    if money < shop.price then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('insufficient_funds'),
            type = 'error'
        })
        return false
    end
    
    -- Remove money
    if Config.Economy.payWithCash then
        Player.Functions.RemoveMoney('cash', shop.price)
    else
        Player.Functions.RemoveMoney('bank', shop.price)
    end
    
    -- Update owner
    if Shops.UpdateOwner(shopId, Player.PlayerData.citizenid) then
        -- Set job
        Player.Functions.SetJob(Config.JobName, Config.BossGrade)
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_purchased'),
            description = locale('shop_purchased_desc', shop.name),
            type = 'success'
        })
        
        return true
    end
    
    return false
end

-- Sell shop
function Shops.Sell(source, shopId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local shop = Shops.GetById(shopId)
    if not shop or shop.owner ~= Player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('not_shop_owner'),
            type = 'error'
        })
        return false
    end
    
    -- Calculate sell price
    local sellPrice = math.floor(shop.price * Config.Economy.sellReturnPercent)
    
    -- Add money
    if Config.Economy.payWithCash then
        Player.Functions.AddMoney('cash', sellPrice)
    else
        Player.Functions.AddMoney('bank', sellPrice)
    end
    
    -- Remove owner
    if Shops.UpdateOwner(shopId, nil) then
        -- Remove job
        Player.Functions.SetJob('unemployed', 0)
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_sold'),
            description = locale('shop_sold_desc', sellPrice),
            type = 'success'
        })
        
        return true
    end
    
    return false
end

-- Spawn service vehicle
function Shops.SpawnServiceVehicle(source, model, coords)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    -- Check job
    if Player.PlayerData.job.name ~= Config.JobName then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('not_mechanic'),
            type = 'error'
        })
        return false
    end
    
    -- Create vehicle
    local vehicle = CreateVehicle(joaat(model), coords.x, coords.y, coords.z, coords.w or 0.0, true, true)
    
    -- Wait for vehicle to exist
    while not DoesEntityExist(vehicle) do
        Wait(10)
    end
    
  
    local plate = 'MECH' .. math.random(1000, 9999)
    lib.setVehicleProperties(vehicle, {
        plate = plate,
        bodyHealth = 1000.0,
        engineHealth = 1000.0,
        fuelLevel = 100.0
    })
    
    -- Set owner
    SetPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
    
    -- Give keys (assuming you have a key system)
    TriggerEvent('vehiclekeys:server:givekeys', source, plate)

    return true
end

-- Employee management
function Shops.AddEmployee(shopId, targetCitizenId, grade)
    return Business.hireEmployee(shopId, targetCitizenId, grade)
end

function Shops.RemoveEmployee(shopId, targetCitizenId)
    return Business.fireEmployee(shopId, targetCitizenId)
end

function Shops.GetEmployees(shopId)
    return Business.getBusinessEmployees(shopId)
end

-- Change employee grade
function Shops.ChangeEmployeeGrade(shopId, targetCitizenId, newGrade)
    return Business.updateEmployeeGrade(shopId, targetCitizenId, newGrade)
end

-- Change employee wage
function Shops.ChangeEmployeeWage(shopId, targetCitizenId, newWage)
    return Business.updateEmployeeWage(shopId, targetCitizenId, newWage)
end

-- Toggle payroll settings
function Shops.TogglePayroll(shopId)
    local shop = Shops.GetById(shopId)
    if shop then
        shop.payrollEnabled = not shop.payrollEnabled
        local query = 'UPDATE mechanic_shops SET payrollEnabled = ? WHERE id = ?'
        MySQL.update.await(query, {shop.payrollEnabled, shopId})
        return true, shop.payrollEnabled
    end
    return false, nil
end

-- Clock in/out system
function Shops.ClockIn(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local query = 'UPDATE mechanic_employees SET on_duty = 1, last_clock_in = NOW() WHERE citizenid = ?'
    return MySQL.update.await(query, {Player.PlayerData.citizenid}) > 0
end

function Shops.ClockOut(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local query = 'UPDATE mechanic_employees SET on_duty = 0 WHERE citizenid = ?'
    return MySQL.update.await(query, {Player.PlayerData.citizenid}) > 0
end

-- Callbacks
lib.callback.register('mechanic:server:getShops', function(source)
    return Shops.GetAll()
end)

lib.callback.register('mechanic:server:purchaseShop', function(source, shopId)
    return Shops.Purchase(source, shopId)
end)

lib.callback.register('mechanic:server:sellShop', function(source, shopId)
    return Shops.Sell(source, shopId)
end)

lib.callback.register('mechanic:server:spawnServiceVehicle', function(source, model, coords)
    return Shops.SpawnServiceVehicle(source, model, coords)
end)

lib.callback.register('mechanic:server:spawnGarageVehicle', function(source, model, coords)
    return Shops.SpawnServiceVehicle(source, model, coords)
end)

-- Employee management callbacks
lib.callback.register('mechanic:server:hireEmployee', function(source, shopId, targetId, grade, wage)
    local success, message = Shops.AddEmployee(shopId, targetId, grade)
    if success then
        -- El wage se establece en el Business.hireEmployee
        return true, message or locale('employee_hired')
    end
    return false, message or locale('hire_failed')
end)

lib.callback.register('mechanic:server:changeEmployeeGrade', function(source, shopId, targetCitizenId, newGrade)
    if Shops.ChangeEmployeeGrade(shopId, targetCitizenId, newGrade) then
        return true, locale('grade_changed')
    end
    return false, locale('change_failed')
end)

lib.callback.register('mechanic:server:changeEmployeeWage', function(source, shopId, targetCitizenId, newWage)
    if Shops.ChangeEmployeeWage(shopId, targetCitizenId, newWage) then
        return true, locale('wage_changed')
    end
    return false, locale('change_failed')
end)

lib.callback.register('mechanic:server:fireEmployee', function(source, shopId, targetCitizenId)
    if Shops.RemoveEmployee(shopId, targetCitizenId) then
        return true, locale('employee_fired')
    end
    return false, locale('fire_failed')
end)

lib.callback.register('mechanic:server:getEmployees', function(source, shopId)
    return Shops.GetEmployees(shopId)
end)

lib.callback.register('mechanic:server:togglePayroll', function(source, shopId)
    return Shops.TogglePayroll(shopId)
end)

lib.callback.register('mechanic:server:getPayrollSettings', function(source, shopId)
    local shop = Shops.GetById(shopId)
    if shop then
        return {enabled = shop.payrollEnabled, frequency = 'weekly', payment_day = 'friday'}
    end
    return nil
end)

lib.callback.register('mechanic:server:clockIn', function(source)
    return Shops.ClockIn(source)
end)

lib.callback.register('mechanic:server:clockOut', function(source)
    return Shops.ClockOut(source)
end)

-- Verificar permisos de empleados
lib.callback.register('mechanic:server:hasEmployeePermission', function(source, shopId, permission)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local citizenid = Player.PlayerData.citizenid
    local rank = Business.getEmployeeRank(citizenid, shopId)
    
    -- Verificar si es dueño o jefe (rank 4)
    if rank >= Config.BossGrade then
        return true
    end
    
    -- Verificar permisos específicos por grade
    local permissions = Config.Employees.permissions[rank]
    if permissions and permissions[permission] then
        return true
    end
    
    return false
end)

-- Events
RegisterNetEvent('mechanic:server:createShop', function(data)
    Shops.Create(data, source)
end)

-- Initialize
CreateThread(function()
    Wait(1000)
    Shops.LoadAll()
end)

return Shops

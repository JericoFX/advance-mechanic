local Shops = {}
local shops = {}
local blips = {}
local zones = {}
local creationMode = false
local creationData = {}

function Shops.LoadShops()
    shops = lib.callback.await('mechanic:server:getShops', false)
    Shops.CreateBlips()
    Shops.CreateZones()
end

function Shops.CreateBlips()
    -- Clear existing blips
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}
    
    for _, shop in ipairs(shops) do
        local blip = AddBlipForCoord(shop.zones.management.x, shop.zones.management.y, shop.zones.management.z)
        SetBlipSprite(blip, Config.Blips.shops.sprite)
        SetBlipColour(blip, Config.Blips.shops.color)
        SetBlipScale(blip, Config.Blips.shops.scale)
        SetBlipDisplay(blip, Config.Blips.shops.display)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)
        
        table.insert(blips, blip)
    end
end

function Shops.CreateZones()
    -- Clear existing zones
    for _, zone in pairs(zones) do
        zone:remove()
    end
    zones = {}
    
    for _, shop in ipairs(shops) do
        -- Management zone
        local mgmtZone = lib.points.new({
            coords = shop.zones.management,
            distance = 5,
            shop = shop
        })
        
        function mgmtZone:nearby()
            if self.currentDistance < 2.0 then
                lib.showTextUI(locale('press_to_manage_shop'))
                
                if IsControlJustPressed(0, 38) then
                    Shops.OpenManagementMenu(self.shop)
                end
            end
        end
        
        function mgmtZone:onExit()
            lib.hideTextUI()
        end
        
        -- Inspection zone
        if shop.zones.inspection then
            exports.ox_target:addSphereZone({
                coords = shop.zones.inspection,
                radius = 5.0,
                options = {
                    {
                        name = 'inspect_vehicle',
                        icon = 'fas fa-search',
                        label = locale('inspect_vehicle'),
                        canInteract = function(entity, distance, coords, name)
                            return cache.vehicle ~= nil
                        end,
                        onSelect = function()
                            local Inspection = require 'client.modules.inspection'
                            Inspection.Inspect(cache.vehicle)
                        end
                    }
                }
            })
        end
        
        table.insert(zones, mgmtZone)
    end
end

function Shops.OpenManagementMenu(shop)
    local options = {
        {
            title = locale('shop_info'),
            description = string.format(locale('owner_format'), shop.owner or locale('no_owner')),
            icon = 'fas fa-info-circle'
        }
    }
    
    local playerJob = QBCore.Functions.GetPlayerData().job
    if playerJob.name == Config.JobName then
        table.insert(options, {
            title = locale('spawn_service_vehicle'),
            icon = 'fas fa-truck',
            onSelect = function()
                Shops.SpawnServiceVehicle(shop)
            end
        })
        
        if playerJob.grade >= Config.BossGrade then
            table.insert(options, {
                title = locale('manage_employees'),
                icon = 'fas fa-users',
                onSelect = function()
                    Shops.ManageEmployees(shop)
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'shop_management',
        title = shop.name,
        options = options
    })
    
    lib.showContext('shop_management')
end

function Shops.SpawnServiceVehicle(shop)
    local vehicles = {}
    
    for vehicleType, data in pairs(Config.Towing.vehicles) do
        table.insert(vehicles, {
            title = data.model,
            icon = 'fas fa-truck',
            onSelect = function()
                local spawnPoint = shop.vehicleSpawns.service[1]
                if spawnPoint then
                    lib.callback('mechanic:server:spawnServiceVehicle', false, function(success)
                        if success then
                            lib.notify({
                                title = locale('vehicle_spawned'),
                                type = 'success'
                            })
                        end
                    end, data.model, spawnPoint)
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'service_vehicles',
        title = locale('service_vehicles'),
        menu = 'shop_management',
        options = vehicles
    })
    
    lib.showContext('service_vehicles')
end

function Shops.StartCreation()
    creationMode = true
    creationData = {
        zones = {},
        lifts = {},
        vehicleSpawns = {
            service = {},
            customer = {}
        }
    }
    
    lib.notify({
        title = locale('shop_creation_started'),
        description = locale('follow_instructions'),
        type = 'info'
    })
    
    -- Create required zones
    for zoneName, zoneConfig in pairs(Config.ShopCreation.requiredZones) do
        Wait(1000)
        lib.showTextUI(string.format(locale('place_zone'), zoneConfig.label))
        
        local coords = lib.getCoords()
        creationData.zones[zoneName] = coords
        
        lib.hideTextUI()
        lib.notify({
            title = string.format(locale('zone_placed'), zoneConfig.label),
            type = 'success'
        })
    end
    
    -- Create lifts
    local addMoreLifts = true
    while addMoreLifts and #creationData.lifts < Config.ShopCreation.maxLifts do
        local lift = {}
        
        lib.showTextUI(locale('place_lift_entry'))
        Wait(1000)
        lift.entry = lib.getCoords()
        lib.hideTextUI()
        
        lib.showTextUI(locale('place_lift_position'))
        Wait(1000)
        lift.pos = lib.getCoords()
        lib.hideTextUI()
        
        lib.showTextUI(locale('place_lift_control'))
        Wait(1000)
        lift.control = lib.getCoords()
        lib.hideTextUI()
        
        table.insert(creationData.lifts, lift)
        
        if #creationData.lifts < Config.ShopCreation.maxLifts then
            local result = lib.alertDialog({
                header = locale('add_another_lift'),
                content = string.format(locale('lifts_added_format'), #creationData.lifts, Config.ShopCreation.maxLifts),
                centered = true,
                cancel = true
            })
            
            addMoreLifts = result == 'confirm'
        else
            addMoreLifts = false
        end
    end
    
    -- Vehicle spawn points
    for spawnType, spawnConfig in pairs(Config.ShopCreation.vehicleSpawns) do
        for i = 1, spawnConfig.max do
            lib.showTextUI(string.format(locale('place_spawn_point'), spawnConfig.label, i))
            Wait(1000)
            local coords = lib.getCoords()
            table.insert(creationData.vehicleSpawns[spawnType], coords)
            lib.hideTextUI()
        end
    end
    
    -- Shop name
    local input = lib.inputDialog(locale('shop_details'), {
        {type = 'input', label = locale('shop_name'), required = true},
        {type = 'number', label = locale('shop_price'), default = Config.ShopCreation.basePrice, min = 0}
    })
    
    if input then
        creationData.name = input[1]
        creationData.price = input[2]
        
        -- Send to server
        TriggerServerEvent('mechanic:server:createShop', creationData)
    end
    
    creationMode = false
end

-- Event handler for shop creation
RegisterNetEvent('mechanic:client:startShopCreation', function()
    Shops.StartCreation()
end)

-- Events
RegisterNetEvent('mechanic:client:shopsUpdated', function(updatedShops)
    shops = updatedShops
    Shops.CreateBlips()
    Shops.CreateZones()
end)

-- Initialize
CreateThread(function()
    Wait(1000)
    Shops.LoadShops()
end)

return Shops

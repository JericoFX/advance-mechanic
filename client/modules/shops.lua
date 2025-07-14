local Shops = {}
local shops = {}
local blips = {}
local zones = {}
local creationMode = false
local creationData = {}
local Inspection = require 'client.modules.inspection'

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
            local inspectionZone = lib.points.new({
                coords = shop.zones.inspection,
                distance = 5,
                shop = shop
            })

            function inspectionZone:nearby()
                if self.currentDistance < 3.0 and cache.vehicle then
                    lib.showTextUI(locale('inspect_vehicle'))

                    if IsControlJustPressed(0, 38) then
                        Inspection.Inspect(cache.vehicle)
                    end
                end
            end

            function inspectionZone:onExit()
                lib.hideTextUI()
            end

            table.insert(zones, inspectionZone)
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

function Shops.ManageEmployees(shop)
    local Employees = require 'client.modules.employees'
    Employees.OpenManagementMenu(shop)
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

    -- Create required zones with freecam
    for zoneName, zoneConfig in pairs(Config.ShopCreation.requiredZones) do
        local coords = Shops.GetPositionWithFreecam(zoneConfig.label)
        if coords then
            creationData.zones[zoneName] = coords
            lib.notify({
                title = string.format(locale('zone_placed'), zoneConfig.label),
                type = 'success'
            })
        else
            lib.notify({
                title = locale('shop_creation_cancelled'),
                type = 'error'
            })
            return
        end
    end

    -- Create lifts with freecam
    local addMoreLifts = true
    while addMoreLifts and #creationData.lifts < Config.ShopCreation.maxLifts do
        local lift = {}

        lift.entry = Shops.GetPositionWithFreecam(locale('place_lift_entry'))
        if not lift.entry then return end

        lift.pos = Shops.GetPositionWithFreecam(locale('place_lift_position'))
        if not lift.pos then return end

        lift.control = Shops.GetPositionWithFreecam(locale('place_lift_control'))
        if not lift.control then return end

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

    -- Vehicle spawn points with freecam
    for spawnType, spawnConfig in pairs(Config.ShopCreation.vehicleSpawns) do
        for i = 1, spawnConfig.max do
            local coords = Shops.GetPositionWithFreecam(string.format(locale('place_spawn_point'), spawnConfig.label, i))
            if coords then
                table.insert(creationData.vehicleSpawns[spawnType], coords)
            else
                return
            end
        end
    end

    -- Shop name
    local input = lib.inputDialog(locale('shop_details'), {
        { type = 'input',  label = locale('shop_name'),  required = true },
        { type = 'number', label = locale('shop_price'), default = Config.ShopCreation.basePrice, min = 0 }
    })

    if input then
        creationData.name = input[1]
        creationData.price = input[2]

        -- Send to server
        TriggerServerEvent('mechanic:server:createShop', creationData)
    end

    creationMode = false
end

function Shops.GetPositionWithFreecam(label)
    lib.showTextUI(string.format(locale('place_zone'), label))

    local coords = nil
    local finished = false

    CreateThread(function()
        while not finished do
            Wait(0)

            -- Get raycast from camera
            local raycast = lib.raycast.fromCamera(511, 4, 10.0)

            if raycast.hit then
                -- Draw marker at hit position
                DrawMarker(
                    1,                                                                   -- type
                    raycast.endCoords.x, raycast.endCoords.y, raycast.endCoords.z - 1.0, -- position
                    0.0, 0.0, 0.0,                                                       -- direction
                    0.0, 0.0, 0.0,                                                       -- rotation
                    2.0, 2.0, 1.0,                                                       -- scale
                    255, 255, 0, 100,                                                    -- color (yellow with alpha)
                    false, true, 2, false, false, false,
                    false                                                                -- bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts
                )

                -- Draw 3D text at hit position
                local onScreen, screenX, screenY = World3dToScreen2d(raycast.endCoords.x, raycast.endCoords.y,
                    raycast.endCoords.z + 1.0)
                if onScreen then
                    SetTextScale(0.35, 0.35)
                    SetTextFont(0)
                    SetTextColour(255, 255, 255, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 150)
                    SetTextEntry("STRING")
                    AddTextComponentString(label)
                    DrawText(screenX, screenY)
                end
            end

            if IsControlJustPressed(0, 38) and raycast.hit then -- E
                coords = raycast.endCoords
                finished = true
            end

            if IsControlJustPressed(0, 194) then -- BACKSPACE
                finished = true
            end
        end
    end)

    while not finished do
        Wait(100)
    end

    lib.hideTextUI()

    return coords
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

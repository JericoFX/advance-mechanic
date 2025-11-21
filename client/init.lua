QBCore = exports[Config.Framework.resourceName]:GetCoreObject()

local function getPlayerJob()
    local playerData = QBCore.Functions.GetPlayerData()
    return playerData and playerData.job
end

local function isMechanic()
    local job = getPlayerJob()
    return job and job.name == Config.JobName
end

-- Load modules
local Inspection = require 'client.modules.inspection'
local Maintenance = require 'client.modules.maintenance'
local Damage = require 'client.modules.damage'
local Lifts = require 'client.modules.lifts'
local Towing = require 'client.modules.towing'
local Shops = require 'client.modules.shops'
local Parts = require 'client.modules.parts'
local Garage = require 'client.modules.garage'
local Missions = require 'client.modules.missions'
local Tuning = require 'client.modules.tuning'
local Billing = require 'client.modules.billing'
local Diagnostic = require 'client.modules.diagnostic'
local FluidEffects = require 'client.modules.fluid_effects'
local VisualEffects = require 'client.modules.visual_effects'

local function resolveTowVehicleConfig(vehicle)
    if not vehicle then return nil end

    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local displayNameLower = displayName and string.lower(displayName) or nil

    for name, towConfig in pairs(Config.Towing.vehicles) do
        local configModel = towConfig.model
        if configModel then
            local configHash = type(configModel) == 'number' and configModel or GetHashKey(configModel)
            if configHash == model then
                return towConfig, name
            end

            if displayNameLower and type(configModel) == 'string' and string.lower(configModel) == displayNameLower then
                return towConfig, name
            end
        end

        if towConfig.models then
            for _, alias in ipairs(towConfig.models) do
                local aliasHash = type(alias) == 'number' and alias or GetHashKey(alias)
                if aliasHash == model then
                    return towConfig, name
                end

                if displayNameLower and type(alias) == 'string' and string.lower(alias) == displayNameLower then
                    return towConfig, name
                end
            end
        end
    end

    return nil
end

-- Initialize player loaded state
local playerLoaded = false

-- Player loaded event
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerLoaded = true
    
    -- Load shops
    Shops.LoadShops()
    
    -- Initialize damage monitoring
    Damage.Monitor()
    
    -- Initialize fluid effects monitoring
    FluidEffects.Monitor()
end)

-- Player unloaded event
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerLoaded = false
end)

-- Resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    if LocalPlayer.state.isLoggedIn then
        playerLoaded = true
        Shops.LoadShops()
        Damage.Monitor()
        FluidEffects.Monitor()
    end
end)

-- Shop updates
RegisterNetEvent('mechanic:client:shopsUpdated', function(shops)
    -- Update zones for all modules
    Lifts.CreateZones(shops)
    Parts.CreateZones(shops)
    Inspection.SetActiveShops(shops)
    
    -- Create garage zones
    for _, shop in ipairs(shops) do
        Garage.CreateZone(shop)
    end
end)

-- Main mechanic menu
lib.registerContext({
    id = 'mechanic_main_menu',
    title = locale('mechanic_menu'),
    options = {
        {
            title = locale('inspect_vehicle'),
            icon = 'fas fa-search',
            onSelect = function()
                local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
                if vehicle then
                    Inspection.Inspect(vehicle)
                else
                    lib.notify({
                        title = locale('no_vehicle_nearby'),
                        type = 'error'
                    })
                end
            end
        },
        {
            title = locale('diagnostic_tablet'),
            icon = 'fas fa-tablet-alt',
            description = locale('advanced_diagnostics'),
            onSelect = function()
                local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
                if vehicle then
                    Diagnostic.OpenTablet(vehicle)
                else
                    lib.notify({
                        title = locale('no_vehicle_nearby'),
                        type = 'error'
                    })
                end
            end
        },
        {
            title = locale('tuning_menu'),
            icon = 'fas fa-cogs',
            description = locale('modify_vehicle'),
            onSelect = function()
                local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
                if vehicle then
                    Tuning.OpenMenu(vehicle)
                else
                    lib.notify({
                        title = locale('no_vehicle_nearby'),
                        type = 'error'
                    })
                end
            end
        },
        {
            title = locale('create_invoice'),
            icon = 'fas fa-file-invoice-dollar',
            description = locale('bill_customer'),
            onSelect = function()
                local closestPlayer, closestDistance = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0, false)
                if closestPlayer then
                    local targetId = GetPlayerServerId(closestPlayer)
                    Billing.CreateInvoice(targetId)
                else
                    lib.notify({
                        title = locale('no_player_nearby'),
                        type = 'error'
                    })
                end
            end
        },
        {
            title = locale('start_mission'),
            icon = 'fas fa-tasks',
            onSelect = function()
                Missions.Start()
            end
        },
        {
            title = locale('tow_vehicle'),
            icon = 'fas fa-truck',
            onSelect = function()
                if cache.vehicle then
                    local towConfig = resolveTowVehicleConfig(cache.vehicle)

                    if towConfig then
                        local targetVehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 10.0, false)
                        if targetVehicle then
                            Towing.AttachVehicle(cache.vehicle, targetVehicle, towConfig)
                        else
                            lib.notify({
                                title = locale('no_vehicle_to_tow'),
                                type = 'error'
                            })
                        end
                    else
                        lib.notify({
                            title = locale('not_tow_vehicle'),
                            type = 'error'
                        })
                    end
                else
                    lib.notify({
                        title = locale('must_be_in_tow_vehicle'),
                        type = 'error'
                    })
                end
            end
        }
    }
})

-- Event to open mechanic menu from server command
RegisterNetEvent('mechanic:client:openMenu', function()
    if isMechanic() then
        lib.showContext('mechanic_main_menu')
    end
end)

-- Keybind for mechanic menu
lib.addKeybind({
    name = 'mechanic_menu',
    description = locale('open_mechanic_menu'),
    defaultKey = 'F6',
    onPressed = function()
        if isMechanic() then
            lib.showContext('mechanic_main_menu')
        end
    end
})

-- ox_target for vehicle maintenance
exports.ox_target:addGlobalVehicle({
    {
        name = 'mechanic:maintenance',
        icon = 'fas fa-oil-can',
        label = locale('perform_maintenance'),
        canInteract = function(entity, distance, coords, name)
            return isMechanic() and distance < 3.0
        end,
        onSelect = function(data)
            local maintenanceOptions = {}
            
            for itemType, itemData in pairs(Config.MaintenanceItems) do
                local hasItem = exports.ox_inventory:Search('count', itemData.item)
                table.insert(maintenanceOptions, {
                    title = itemData.label,
                    icon = 'fas fa-wrench',
                    disabled = hasItem < 1,
                    metadata = {
                        {label = locale('in_inventory'), value = hasItem}
                    },
                    onSelect = function()
                        Maintenance.Perform(data.entity, itemType)
                    end
                })
            end
            
            lib.registerContext({
                id = 'maintenance_menu',
                title = locale('vehicle_maintenance'),
                options = maintenanceOptions
            })
            
            lib.showContext('maintenance_menu')
        end
    }
})

-- Sync vehicle properties from server
RegisterNetEvent('mechanic:client:syncVehicleProperties', function(netId, props)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        lib.setVehicleProperties(vehicle, props)
    end
end)

-- Export functions for external use
exports('inspectVehicle', function(vehicle)
    return Inspection.Inspect(vehicle)
end)

exports('isPlayerMechanic', function()
    return isMechanic()
end)

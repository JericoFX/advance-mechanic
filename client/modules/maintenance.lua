local Maintenance = {}
local VisualEffects = require 'client.modules.visual_effects'

function Maintenance.Perform(vehicle, item)
if not DoesEntityExist(vehicle) then return end
    
    -- Ensure the hood is open for engine-related maintenance
    if (item == 'oil' or item == 'coolant' or item == 'battery') and not VisualEffects.CheckHoodOpen(vehicle) then
        lib.notify({
            title = locale('open_hood_first'),
            description = locale('hood_must_be_open_for_engine'),
            type = 'error'
        })
        return
    end
    
    local maintenanceItem = Config.MaintenanceItems[item]
    if not maintenanceItem then
        lib.notify({
            title = locale('invalid_item'),
            type = 'error'
        })
        return
    end
    
    if not exports.ox_inventory:Search('count', maintenanceItem.item) then
        lib.notify({
            title = string.format(locale('missing_item'), maintenanceItem.label),
            type = 'error'
        })
        return
    end
    
    -- Start visual effects
    local effects = nil
    if item == 'oil' or item == 'coolant' then
        effects = VisualEffects.EngineRepairEffect(vehicle, Config.Animations.repair.duration)
    end
    
    local progress = lib.progressBar({
        duration = Config.Animations.repair.duration,
        label = string.format(locale('performing_maintenance'), maintenanceItem.label),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true
        },
        anim = {
            dict = Config.Animations.repair.dict,
            clip = Config.Animations.repair.anim
        }
    })
    
    if progress then
        -- Simulated effect of maintenance
        local health = GetVehicleEngineHealth(vehicle) + maintenanceItem.restores
        SetVehicleEngineHealth(vehicle, math.min(health, 1000.0))
        
        exports.ox_inventory:RemoveItem(maintenanceItem.item, 1)
        
        lib.notify({
            title = string.format(locale('maintenance_complete'), maintenanceItem.label),
            type = 'success'
        })
    end
end

function Maintenance.RepairAll(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local repairCost = 1000 -- Base repair cost
    
    local alert = lib.alertDialog({
        header = locale('repair_all_systems'),
        content = locale('repair_cost_confirmation', repairCost),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        -- Apply welding effects for major repairs
        local effects = VisualEffects.WeldingEffect(vehicle, 15000)
        
        local progress = lib.progressBar({
            duration = 15000,
            label = locale('repairing_all_systems'),
            useWhileDead = false,
            canCancel = false,
            disable = {
                car = true,
                move = true
            }
        })
        
        if progress then
            lib.callback('mechanic:server:repairVehicle', false, function(success)
                if success then
                    SetVehicleFixed(vehicle)
                    SetVehicleEngineHealth(vehicle, 1000.0)
                    SetVehicleBodyHealth(vehicle, 1000.0)
                    SetVehiclePetrolTankHealth(vehicle, 1000.0)
                    
                    -- Reset all inspection values
                    local vehicleState = Entity(vehicle).state
                    for name, _ in pairs(Config.Inspection.checkPoints) do
                        vehicleState:set('inspection_' .. name, 0, true)
                    end
                    
                    lib.notify({
                        title = locale('repair_complete'),
                        type = 'success'
                    })
                end
            end, VehToNet(vehicle), repairCost)
        end
    end
end

function Maintenance.RefillAllFluids(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local progress = lib.progressBar({
        duration = 10000,
        label = locale('refilling_all_fluids'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_player'
        }
    })
    
    if progress then
        local vehicleState = Entity(vehicle).state
        
        -- Set all fluid levels to 100%
        vehicleState:set('oilLevel', 100, true)
        vehicleState:set('coolantLevel', 100, true)
        vehicleState:set('brakeFluidLevel', 100, true)
        vehicleState:set('transmissionFluidLevel', 100, true)
        vehicleState:set('powerSteeringLevel', 100, true)
        
        lib.notify({
            title = locale('fluids_refilled'),
            description = locale('all_fluids_topped_up'),
            type = 'success'
        })
    end
end

return Maintenance

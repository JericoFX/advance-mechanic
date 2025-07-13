local Tuning = {}

local performanceMods = {
    [11] = {label = locale('engine'), maxLevel = 4, basePrice = 5000},
    [12] = {label = locale('brakes'), maxLevel = 3, basePrice = 3000},
    [13] = {label = locale('transmission'), maxLevel = 3, basePrice = 4000},
    [15] = {label = locale('suspension'), maxLevel = 4, basePrice = 3500},
    [16] = {label = locale('armor'), maxLevel = 5, basePrice = 7500},
    [18] = {label = locale('turbo'), maxLevel = 1, basePrice = 15000}
}

function Tuning.OpenMenu(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local vehicleState = Entity(vehicle).state
    if not vehicleState.onLift then
        lib.notify({
            title = locale('vehicle_must_be_on_lift'),
            type = 'error'
        })
        return
    end
    
    local options = {
        {
            title = locale('performance_tuning'),
            description = locale('upgrade_vehicle_performance'),
            icon = 'fas fa-tachometer-alt',
            onSelect = function()
                Tuning.PerformanceMenu(vehicle)
            end
        },
        {
            title = locale('visual_tuning'),
            description = locale('customize_vehicle_appearance'),
            icon = 'fas fa-paint-brush',
            onSelect = function()
                Tuning.VisualMenu(vehicle)
            end
        },
        {
            title = locale('nitro_system'),
            description = locale('install_nitro_system'),
            icon = 'fas fa-fire',
            onSelect = function()
                Tuning.NitroMenu(vehicle)
            end
        }
    }
    
    lib.registerContext({
        id = 'tuning_menu',
        title = locale('tuning_menu'),
        options = options
    })
    
    lib.showContext('tuning_menu')
end

function Tuning.PerformanceMenu(vehicle)
    local options = {}
    
    for modType, modData in pairs(performanceMods) do
        local currentLevel = GetVehicleMod(vehicle, modType)
        local maxLevel = GetNumVehicleMods(vehicle, modType) - 1
        
        if modType == 18 then -- Turbo
            currentLevel = IsToggleModOn(vehicle, modType) and 1 or -1
            maxLevel = 1
        end
        
        local price = modData.basePrice * (currentLevel + 2)
        local nextLevel = math.min(currentLevel + 1, maxLevel)
        
        table.insert(options, {
            title = modData.label,
            description = locale('current_level', currentLevel + 1, maxLevel + 1),
            icon = 'fas fa-wrench',
            progress = ((currentLevel + 1) / (maxLevel + 1)) * 100,
            colorScheme = currentLevel == maxLevel and 'green' or 'orange',
            disabled = currentLevel >= maxLevel,
            metadata = {
                {label = locale('price'), value = '$' .. price}
            },
            onSelect = function()
                Tuning.ApplyPerformanceMod(vehicle, modType, nextLevel, price)
            end
        })
    end
    
    lib.registerContext({
        id = 'performance_menu',
        title = locale('performance_tuning'),
        menu = 'tuning_menu',
        options = options
    })
    
    lib.showContext('performance_menu')
end

function Tuning.ApplyPerformanceMod(vehicle, modType, level, price)
    local progress = lib.progressBar({
        duration = 10000,
        label = locale('installing_upgrade'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    })
    
    if progress then
        lib.callback('mechanic:server:applyPerformanceMod', false, function(success)
            if success then
                if modType == 18 then -- Turbo
                    ToggleVehicleMod(vehicle, modType, level == 1)
                else
                    SetVehicleMod(vehicle, modType, level, false)
                end
                
                lib.notify({
                    title = locale('upgrade_installed'),
                    type = 'success'
                })
                
                -- Sync to server
                local props = lib.getVehicleProperties(vehicle)
                TriggerServerEvent('mechanic:server:saveVehicleProps', VehToNet(vehicle), props)
            end
        end, price, modType, level)
    end
end

function Tuning.VisualMenu(vehicle)
    local options = {
        {
            title = locale('spoilers'),
            icon = 'fas fa-car',
            onSelect = function()
                Tuning.ModMenu(vehicle, 0, locale('spoilers'), 3000)
            end
        },
        {
            title = locale('front_bumper'),
            icon = 'fas fa-car',
            onSelect = function()
                Tuning.ModMenu(vehicle, 1, locale('front_bumper'), 2500)
            end
        },
        {
            title = locale('rear_bumper'),
            icon = 'fas fa-car',
            onSelect = function()
                Tuning.ModMenu(vehicle, 2, locale('rear_bumper'), 2500)
            end
        },
        {
            title = locale('side_skirts'),
            icon = 'fas fa-car',
            onSelect = function()
                Tuning.ModMenu(vehicle, 3, locale('side_skirts'), 2000)
            end
        },
        {
            title = locale('exhaust'),
            icon = 'fas fa-car',
            onSelect = function()
                Tuning.ModMenu(vehicle, 4, locale('exhaust'), 1500)
            end
        },
        {
            title = locale('wheels'),
            icon = 'fas fa-circle',
            onSelect = function()
                Tuning.WheelMenu(vehicle)
            end
        },
        {
            title = locale('windows'),
            icon = 'fas fa-square',
            onSelect = function()
                Tuning.WindowTintMenu(vehicle)
            end
        }
    }
    
    lib.registerContext({
        id = 'visual_menu',
        title = locale('visual_tuning'),
        menu = 'tuning_menu',
        options = options
    })
    
    lib.showContext('visual_menu')
end

function Tuning.ModMenu(vehicle, modType, label, basePrice)
    local options = {}
    local currentMod = GetVehicleMod(vehicle, modType)
    local modCount = GetNumVehicleMods(vehicle, modType)
    
    for i = -1, modCount - 1 do
        local modLabel = i == -1 and locale('stock') or locale('option_number', i + 1)
        local price = i == -1 and 0 or basePrice + (i * 500)
        
        table.insert(options, {
            title = modLabel,
            icon = currentMod == i and 'fas fa-check-circle' or 'fas fa-circle',
            iconColor = currentMod == i and '#51cf66' or nil,
            disabled = currentMod == i,
            metadata = {
                {label = locale('price'), value = '$' .. price}
            },
            onSelect = function()
                Tuning.ApplyVisualMod(vehicle, modType, i, price)
            end
        })
    end
    
    lib.registerContext({
        id = 'mod_selection',
        title = label,
        menu = 'visual_menu',
        options = options
    })
    
    lib.showContext('mod_selection')
end

function Tuning.ApplyVisualMod(vehicle, modType, modIndex, price)
    local progress = lib.progressBar({
        duration = 5000,
        label = locale('installing_part'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_player'
        }
    })
    
    if progress then
        lib.callback('mechanic:server:applyVisualMod', false, function(success)
            if success then
                SetVehicleMod(vehicle, modType, modIndex, false)
                
                lib.notify({
                    title = locale('part_installed'),
                    type = 'success'
                })
                
                local props = lib.getVehicleProperties(vehicle)
                TriggerServerEvent('mechanic:server:saveVehicleProps', VehToNet(vehicle), props)
            end
        end, price, modType, modIndex)
    end
end

function Tuning.NitroMenu(vehicle)
    local vehicleState = Entity(vehicle).state
    local hasNitro = vehicleState.hasNitro or false
    local nitroLevel = vehicleState.nitroLevel or 0
    
    local options = {
        {
            title = locale('install_nitro_50'),
            description = locale('nitro_50_desc'),
            icon = 'fas fa-fire',
            disabled = hasNitro,
            metadata = {
                {label = locale('price'), value = '$5000'},
                {label = locale('capacity'), value = '50 shots'}
            },
            onSelect = function()
                Tuning.InstallNitro(vehicle, 50, 5000)
            end
        },
        {
            title = locale('install_nitro_100'),
            description = locale('nitro_100_desc'),
            icon = 'fas fa-fire',
            disabled = hasNitro,
            metadata = {
                {label = locale('price'), value = '$8000'},
                {label = locale('capacity'), value = '100 shots'}
            },
            onSelect = function()
                Tuning.InstallNitro(vehicle, 100, 8000)
            end
        },
        {
            title = locale('refill_nitro'),
            description = locale('refill_nitro_desc'),
            icon = 'fas fa-fill',
            disabled = not hasNitro,
            metadata = {
                {label = locale('price'), value = '$2000'},
                {label = locale('current_level'), value = nitroLevel .. '%'}
            },
            onSelect = function()
                Tuning.RefillNitro(vehicle, 2000)
            end
        },
        {
            title = locale('remove_nitro'),
            description = locale('remove_nitro_desc'),
            icon = 'fas fa-trash',
            disabled = not hasNitro,
            onSelect = function()
                Tuning.RemoveNitro(vehicle)
            end
        }
    }
    
    lib.registerContext({
        id = 'nitro_menu',
        title = locale('nitro_system'),
        menu = 'tuning_menu',
        options = options
    })
    
    lib.showContext('nitro_menu')
end

function Tuning.InstallNitro(vehicle, capacity, price)
    local progress = lib.progressBar({
        duration = 15000,
        label = locale('installing_nitro'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    })
    
    if progress then
        lib.callback('mechanic:server:installNitro', false, function(success)
            if success then
                local vehicleState = Entity(vehicle).state
                vehicleState:set('hasNitro', true, true)
                vehicleState:set('nitroCapacity', capacity, true)
                vehicleState:set('nitroLevel', 100, true)
                
                lib.notify({
                    title = locale('nitro_installed'),
                    type = 'success'
                })
            end
        end, VehToNet(vehicle), capacity, price)
    end
end

return Tuning

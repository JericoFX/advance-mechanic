local Diagnostic = {}

function Diagnostic.OpenTablet(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local vehicleData = lib.callback.await('mechanic:server:getVehicleData', false, plate)
    
    if not vehicleData then
        lib.notify({
            title = locale('no_vehicle_data'),
            type = 'error'
        })
        return
    end
    
    -- Main diagnostic menu with tablet-like appearance
    local options = {
        {
            title = locale('vehicle_information'),
            description = locale('view_vehicle_details'),
            icon = 'fas fa-car',
            iconColor = '#3498db',
            arrow = true,
            onSelect = function()
                Diagnostic.ShowVehicleInfo(vehicle, vehicleData)
            end
        },
        {
            title = locale('system_diagnostics'),
            description = locale('run_full_diagnostic'),
            icon = 'fas fa-laptop-medical',
            iconColor = '#e74c3c',
            arrow = true,
            onSelect = function()
                Diagnostic.RunSystemDiagnostic(vehicle, vehicleData)
            end
        },
        {
            title = locale('maintenance_history'),
            description = locale('view_repair_history'),
            icon = 'fas fa-history',
            iconColor = '#f39c12',
            arrow = true,
            onSelect = function()
                Diagnostic.ShowMaintenanceHistory(vehicleData)
            end
        },
        {
            title = locale('performance_analysis'),
            description = locale('analyze_vehicle_performance'),
            icon = 'fas fa-chart-line',
            iconColor = '#9b59b6',
            arrow = true,
            onSelect = function()
                Diagnostic.PerformanceAnalysis(vehicle)
            end
        },
        {
            title = locale('damage_report'),
            description = locale('detailed_damage_assessment'),
            icon = 'fas fa-exclamation-triangle',
            iconColor = '#e67e22',
            arrow = true,
            onSelect = function()
                Diagnostic.DamageReport(vehicle)
            end
        },
        {
            title = locale('fluid_levels'),
            description = locale('check_all_fluid_levels'),
            icon = 'fas fa-oil-can',
            iconColor = '#1abc9c',
            arrow = true,
            onSelect = function()
                Diagnostic.FluidLevels(vehicle, vehicleData)
            end
        }
    }
    
    lib.registerContext({
        id = 'diagnostic_tablet',
        title = locale('diagnostic_tablet'),
        options = options
    })
    
    lib.showContext('diagnostic_tablet')
end

function Diagnostic.ShowVehicleInfo(vehicle, vehicleData)
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model)
    local plate = GetVehicleNumberPlateText(vehicle)
    local bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) / 10)
    local engineHealth = math.floor(GetVehicleEngineHealth(vehicle) / 10)
    
    local options = {
        {
            title = locale('model'),
            description = modelName,
            icon = 'fas fa-tag',
            iconColor = '#3498db',
            disabled = true
        },
        {
            title = locale('plate'),
            description = plate,
            icon = 'fas fa-id-card',
            iconColor = '#2ecc71',
            disabled = true
        },
        {
            title = locale('owner'),
            description = vehicleData.owner or locale('unknown'),
            icon = 'fas fa-user',
            iconColor = '#e74c3c',
            disabled = true
        },
        {
            title = locale('body_condition'),
            description = locale('health_percentage', bodyHealth),
            icon = 'fas fa-car-crash',
            progress = bodyHealth,
            colorScheme = bodyHealth > 70 and 'green' or bodyHealth > 40 and 'orange' or 'red',
            disabled = true
        },
        {
            title = locale('engine_condition'),
            description = locale('health_percentage', engineHealth),
            icon = 'fas fa-cogs',
            progress = engineHealth,
            colorScheme = engineHealth > 70 and 'green' or engineHealth > 40 and 'orange' or 'red',
            disabled = true
        },
        {
            title = locale('mileage'),
            description = locale('kilometers', vehicleData.mileage or 0),
            icon = 'fas fa-tachometer-alt',
            iconColor = '#9b59b6',
            disabled = true
        }
    }
    
    lib.registerContext({
        id = 'vehicle_info',
        title = locale('vehicle_information'),
        menu = 'diagnostic_tablet',
        options = options
    })
    
    lib.showContext('vehicle_info')
end

function Diagnostic.RunSystemDiagnostic(vehicle, vehicleData)
    local progress = lib.progressBar({
        duration = 8000,
        label = locale('running_diagnostics'),
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true
        },
        anim = {
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
            clip = 'idle_a'
        },
        prop = {
            model = 'prop_cs_tablet',
            pos = vec3(0.03, 0.002, -0.0),
            rot = vec3(10.0, 160.0, 0.0)
        }
    })
    
    if progress then
        local diagnosticResults = {}
        local checkpoints = Config.Inspection.checkPoints
        
        for name, checkpoint in pairs(checkpoints) do
            local vehicleState = Entity(vehicle).state
            local degradation = vehicleState['inspection_' .. name] or math.random(0, 40) / 100
            local health = math.floor((1 - degradation) * 100)
            
            table.insert(diagnosticResults, {
                title = checkpoint.label,
                description = locale('system_status'),
                icon = health > 70 and 'fas fa-check-circle' or health > 40 and 'fas fa-exclamation-circle' or 'fas fa-times-circle',
                iconColor = health > 70 and '#2ecc71' or health > 40 and '#f39c12' or '#e74c3c',
                progress = health,
                colorScheme = health > 70 and 'green' or health > 40 and 'orange' or 'red',
                metadata = {
                    {label = locale('condition'), value = health .. '%'},
                    {label = locale('status'), value = health > 70 and locale('good') or health > 40 and locale('fair') or locale('poor')}
                },
                disabled = true
            })
        end
        
        table.insert(diagnosticResults, {
            title = locale('generate_report'),
            description = locale('create_detailed_report'),
            icon = 'fas fa-file-pdf',
            iconColor = '#3498db',
            onSelect = function()
                Diagnostic.GenerateReport(vehicle, diagnosticResults)
            end
        })
        
        lib.registerContext({
            id = 'diagnostic_results',
            title = locale('diagnostic_results'),
            menu = 'diagnostic_tablet',
            options = diagnosticResults
        })
        
        lib.showContext('diagnostic_results')
    end
end

function Diagnostic.ShowMaintenanceHistory(vehicleData)
    local history = vehicleData.maintenanceHistory or {}
    local options = {}
    
    if #history == 0 then
        table.insert(options, {
            title = locale('no_history'),
            description = locale('no_maintenance_recorded'),
            icon = 'fas fa-info-circle',
            iconColor = '#95a5a6',
            disabled = true
        })
    else
        for i, record in ipairs(history) do
            table.insert(options, {
                title = record.type,
                description = locale('performed_on', record.date),
                icon = 'fas fa-wrench',
                iconColor = '#3498db',
                metadata = {
                    {label = locale('mechanic'), value = record.mechanic},
                    {label = locale('cost'), value = '$' .. record.cost},
                    {label = locale('mileage'), value = record.mileage .. ' km'}
                },
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = 'maintenance_history',
        title = locale('maintenance_history'),
        menu = 'diagnostic_tablet',
        options = options
    })
    
    lib.showContext('maintenance_history')
end

function Diagnostic.PerformanceAnalysis(vehicle)
    local handling = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    local acceleration = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
    local braking = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce')
    
    local engineMod = GetVehicleMod(vehicle, 11)
    local brakeMod = GetVehicleMod(vehicle, 12)
    local transmissionMod = GetVehicleMod(vehicle, 13)
    local turbo = IsToggleModOn(vehicle, 18)
    
    local options = {
        {
            title = locale('top_speed'),
            description = locale('kmh', math.floor(handling * 3.6)),
            icon = 'fas fa-tachometer-alt',
            iconColor = '#e74c3c',
            progress = (handling / 200) * 100,
            colorScheme = 'blue',
            disabled = true
        },
        {
            title = locale('acceleration'),
            description = locale('zero_to_100'),
            icon = 'fas fa-rocket',
            iconColor = '#f39c12',
            progress = (acceleration / 0.5) * 100,
            colorScheme = 'orange',
            disabled = true
        },
        {
            title = locale('braking_power'),
            description = locale('braking_efficiency'),
            icon = 'fas fa-stop-circle',
            iconColor = '#e67e22',
            progress = (braking / 2.0) * 100,
            colorScheme = 'red',
            disabled = true
        },
        {
            title = locale('engine_upgrade'),
            description = locale('level_x', engineMod + 1),
            icon = 'fas fa-cogs',
            iconColor = '#3498db',
            progress = engineMod >= 0 and ((engineMod + 1) / 5) * 100 or 0,
            colorScheme = 'green',
            disabled = true
        },
        {
            title = locale('brake_upgrade'),
            description = locale('level_x', brakeMod + 1),
            icon = 'fas fa-compact-disc',
            iconColor = '#9b59b6',
            progress = brakeMod >= 0 and ((brakeMod + 1) / 4) * 100 or 0,
            colorScheme = 'purple',
            disabled = true
        },
        {
            title = locale('transmission_upgrade'),
            description = locale('level_x', transmissionMod + 1),
            icon = 'fas fa-exchange-alt',
            iconColor = '#1abc9c',
            progress = transmissionMod >= 0 and ((transmissionMod + 1) / 4) * 100 or 0,
            colorScheme = 'teal',
            disabled = true
        },
        {
            title = locale('turbo'),
            description = turbo and locale('installed') or locale('not_installed'),
            icon = 'fas fa-fan',
            iconColor = turbo and '#2ecc71' or '#95a5a6',
            disabled = true
        }
    }
    
    lib.registerContext({
        id = 'performance_analysis',
        title = locale('performance_analysis'),
        menu = 'diagnostic_tablet',
        options = options
    })
    
    lib.showContext('performance_analysis')
end

function Diagnostic.DamageReport(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local petrolTankHealth = GetVehiclePetrolTankHealth(vehicle)
    
    local options = {}
    
    -- Check each part
    for i = 0, 5 do
        local isDamaged = IsVehicleDoorDamaged(vehicle, i)
        if isDamaged then
            table.insert(options, {
                title = locale('door_x', i + 1),
                description = locale('damaged'),
                icon = 'fas fa-door-open',
                iconColor = '#e74c3c',
                metadata = {
                    {label = locale('status'), value = locale('needs_repair')}
                },
                disabled = true
            })
        end
    end
    
    -- Check windows
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then
            table.insert(options, {
                title = locale('window_x', i + 1),
                description = locale('broken'),
                icon = 'fas fa-window-close',
                iconColor = '#e74c3c',
                metadata = {
                    {label = locale('status'), value = locale('needs_replacement')}
                },
                disabled = true
            })
        end
    end
    
    -- Check tires
    for i = 0, 5 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            table.insert(options, {
                title = locale('tire_x', i + 1),
                description = locale('burst'),
                icon = 'fas fa-circle',
                iconColor = '#e74c3c',
                metadata = {
                    {label = locale('status'), value = locale('needs_replacement')}
                },
                disabled = true
            })
        end
    end
    
    if #options == 0 then
        table.insert(options, {
            title = locale('no_visible_damage'),
            description = locale('vehicle_appears_undamaged'),
            icon = 'fas fa-check-circle',
            iconColor = '#2ecc71',
            disabled = true
        })
    end
    
    lib.registerContext({
        id = 'damage_report',
        title = locale('damage_report'),
        menu = 'diagnostic_tablet',
        options = options
    })
    
    lib.showContext('damage_report')
end

function Diagnostic.FluidLevels(vehicle, vehicleData)
    local vehicleState = Entity(vehicle).state
    
    local fluids = {
        {
            name = 'oil',
            label = locale('engine_oil'),
            level = vehicleState.oilLevel or math.random(30, 90),
            icon = 'fas fa-oil-can',
            color = '#34495e'
        },
        {
            name = 'coolant',
            label = locale('coolant'),
            level = vehicleState.coolantLevel or math.random(40, 95),
            icon = 'fas fa-thermometer-half',
            color = '#3498db'
        },
        {
            name = 'brake_fluid',
            label = locale('brake_fluid'),
            level = vehicleState.brakeFluidLevel or math.random(50, 95),
            icon = 'fas fa-compress',
            color = '#e74c3c'
        },
        {
            name = 'transmission_fluid',
            label = locale('transmission_fluid'),
            level = vehicleState.transmissionFluidLevel or math.random(60, 95),
            icon = 'fas fa-cog',
            color = '#f39c12'
        },
        {
            name = 'power_steering',
            label = locale('power_steering_fluid'),
            level = vehicleState.powerSteeringLevel or math.random(70, 95),
            icon = 'fas fa-steering-wheel',
            color = '#9b59b6'
        }
    }
    
    local options = {}
    
    for _, fluid in ipairs(fluids) do
        local colorScheme = fluid.level > 70 and 'green' or fluid.level > 40 and 'orange' or 'red'
        
        table.insert(options, {
            title = fluid.label,
            description = locale('level_percentage', fluid.level),
            icon = fluid.icon,
            iconColor = fluid.color,
            progress = fluid.level,
            colorScheme = colorScheme,
            metadata = {
                {label = locale('status'), value = fluid.level > 70 and locale('good') or fluid.level > 40 and locale('low') or locale('critical')},
                {label = locale('action'), value = fluid.level < 70 and locale('refill_required') or locale('no_action_needed')}
            },
            disabled = true
        })
    end
    
    table.insert(options, {
        title = locale('refill_all_fluids'),
        description = locale('top_up_all_fluids'),
        icon = 'fas fa-fill-drip',
        iconColor = '#2ecc71',
        onSelect = function()
            local Maintenance = require 'client.modules.maintenance'
            Maintenance.RefillAllFluids(vehicle)
        end
    })
    
    lib.registerContext({
        id = 'fluid_levels',
        title = locale('fluid_levels'),
        menu = 'diagnostic_tablet',
        options = options
    })
    
    lib.showContext('fluid_levels')
end

function Diagnostic.GenerateReport(vehicle, diagnosticData)
    local plate = GetVehicleNumberPlateText(vehicle)
    
    lib.callback('mechanic:server:generateDiagnosticReport', false, function(success)
        if success then
            lib.notify({
                title = locale('report_generated'),
                description = locale('report_saved_to_database'),
                type = 'success'
            })
        end
    end, plate, diagnosticData)
end

return Diagnostic

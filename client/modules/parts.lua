local Parts = {}
local Framework = require 'shared.framework'
local partsZones = {}

function Parts.CreateZones(shops)
    -- Clear existing zones
    for _, zone in pairs(partsZones) do
        zone:remove()
    end
    partsZones = {}
    
    for _, shop in ipairs(shops) do
        if shop.zones.parts then
            local partsZone = lib.points.new({
                coords = shop.zones.parts,
                distance = 5,
                shop = shop
            })
            
            function partsZone:nearby()
                if self.currentDistance < 2.0 then
                    lib.showTextUI(locale('press_to_open_parts_shop'))
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        Parts.OpenShop(self.shop)
                    end
                end
            end
            
            function partsZone:onExit()
                lib.hideTextUI()
            end
            
            table.insert(partsZones, partsZone)
        end
    end
end

function Parts.OpenShop(shop)
    local options = {}
    
    -- Create menu options for each part
    for partId, partData in pairs(Config.VehicleParts) do
        local price = math.floor(partData.price * Config.Economy.partMarkup)
        
        table.insert(options, {
            title = partData.label,
            description = locale('price_format', price),
            icon = 'fas fa-cog',
            metadata = {
                {label = locale('item'), value = partData.item},
                {label = locale('stock'), value = locale('in_stock')}
            },
            onSelect = function()
                Parts.PurchasePart(partId, price)
            end
        })
    end
    
    lib.registerContext({
        id = 'parts_shop',
        title = locale('parts_shop'),
        options = options
    })
    
    lib.showContext('parts_shop')
end

function Parts.PurchasePart(partId, price)
    local partData = Config.VehicleParts[partId]
    if not partData then return end
    
    -- Create input dialog for quantity
    local input = lib.inputDialog(locale('purchase_part'), {
        {
            type = 'number',
            label = locale('quantity'),
            default = 1,
            min = 1,
            max = 10
        }
    })
    
    if input and input[1] then
        local quantity = input[1]
        local totalPrice = price * quantity
        
        -- Confirm purchase
        local alert = lib.alertDialog({
            header = locale('confirm_purchase'),
            content = locale('purchase_confirmation', quantity, partData.label, totalPrice),
            centered = true,
            cancel = true
        })
        
        if alert == 'confirm' then
            lib.callback('mechanic:server:purchasePart', false, function(success)
                if success then
                    lib.notify({
                        title = locale('purchase_successful'),
                        type = 'success'
                    })
                else
                    lib.notify({
                        title = locale('insufficient_funds'),
                        type = 'error'
                    })
                end
            end, partId, quantity, totalPrice)
        end
    end
end

function Parts.InstallPart(vehicle, partType)
    if not DoesEntityExist(vehicle) then return end
    
    local partData = Config.VehicleParts[partType]
    if not partData then return end
    
    -- Check if player has the part
    local hasItem = exports.ox_inventory:Search('count', partData.item)
    if hasItem < 1 then
        lib.notify({
            title = locale('missing_part'),
            description = locale('need_part', partData.label),
            type = 'error'
        })
        return
    end
    
    -- Progress bar for installation
    if lib.progressBar({
        duration = Config.Animations.repair.duration,
        label = locale('installing_part', partData.label),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = Config.Animations.repair.dict,
            clip = Config.Animations.repair.anim
        }
    }) then
        -- Remove item and apply repair
        exports.ox_inventory:RemoveItem(partData.item, 1)
        
        -- Apply visual repair based on part type
        if partType == 'door' then
            for i = 0, 5 do
                SetVehicleDoorBroken(vehicle, i, false)
            end
        elseif partType == 'window' then
            for i = 0, 7 do
                FixVehicleWindow(vehicle, i)
            end
        elseif partType == 'wheel' then
            for i = 0, 5 do
                SetVehicleTyreFixed(vehicle, i)
            end
        elseif partType == 'hood' then
            SetVehicleDoorBroken(vehicle, 4, false)
        elseif partType == 'trunk' then
            SetVehicleDoorBroken(vehicle, 5, false)
        end
        
        lib.notify({
            title = locale('part_installed'),
            description = locale('installed_successfully', partData.label),
            type = 'success'
        })
    end
end

-- ox_target integration for vehicle parts
exports.ox_target:addGlobalVehicle({
    {
        name = 'mechanic:install_parts',
        icon = 'fas fa-wrench',
        label = locale('install_parts'),
        canInteract = function(entity, distance, coords, name)
            local playerData = Framework.GetPlayerData()
            return playerData.job.name == Config.JobName and distance < 3.0
        end,
        onSelect = function(data)
            local vehicle = data.entity
            Parts.OpenInstallMenu(vehicle)
        end
    }
})

function Parts.OpenInstallMenu(vehicle)
    local options = {}
    
    for partId, partData in pairs(Config.VehicleParts) do
        local hasItem = exports.ox_inventory:Search('count', partData.item)
        
        table.insert(options, {
            title = partData.label,
            icon = hasItem > 0 and 'fas fa-check-circle' or 'fas fa-times-circle',
            disabled = hasItem < 1,
            metadata = {
                {label = locale('in_inventory'), value = hasItem}
            },
            onSelect = function()
                Parts.InstallPart(vehicle, partId)
            end
        })
    end
    
    lib.registerContext({
        id = 'install_parts_menu',
        title = locale('install_parts'),
        options = options
    })
    
    lib.showContext('install_parts_menu')
end

return Parts

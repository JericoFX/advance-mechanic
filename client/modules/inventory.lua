local Inventory = {}

local shopInventories = {}

function Inventory.OpenShopInventory(shopId)
    exports.ox_inventory:openInventory('stash', 'mechanic_shop_' .. shopId)
end

function Inventory.CreatePartMenu(shop)
    local options = {}
    
    -- Maintenance items
    local maintenanceHeader = {
        title = locale('maintenance_supplies'),
        icon = 'fas fa-toolbox',
        iconColor = '#3498db',
        disabled = true
    }
    table.insert(options, maintenanceHeader)
    
    for itemKey, itemData in pairs(Config.MaintenanceItems) do
        local price = math.floor(itemData.price or 100)
        table.insert(options, {
            title = itemData.label,
            description = locale('price_format', price),
            icon = 'fas fa-oil-can',
            metadata = {
                {label = locale('restores'), value = itemData.restores .. '%'}
            },
            onSelect = function()
                Inventory.PurchaseItem(itemData.item, price, 1)
            end
        })
    end
    
    -- Vehicle parts
    local partsHeader = {
        title = locale('vehicle_parts'),
        icon = 'fas fa-car',
        iconColor = '#e74c3c',
        disabled = true
    }
    table.insert(options, partsHeader)
    
    for partKey, partData in pairs(Config.VehicleParts) do
        local price = math.floor(partData.price * Config.Economy.partMarkup)
        table.insert(options, {
            title = partData.label,
            description = locale('price_format', price),
            icon = 'fas fa-cog',
            onSelect = function()
                Inventory.PurchaseItem(partData.item, price, 1)
            end
        })
    end
    
    -- Tools
    local toolsHeader = {
        title = locale('tools'),
        icon = 'fas fa-wrench',
        iconColor = '#f39c12',
        disabled = true
    }
    table.insert(options, toolsHeader)
    
    for _, toolCategory in pairs(Config.Tools) do
        for _, tool in ipairs(toolCategory) do
            local price = 500 -- Default tool price
            table.insert(options, {
                title = tool.label,
                description = locale('price_format', price),
                icon = 'fas fa-tools',
                onSelect = function()
                    Inventory.PurchaseItem(tool.item, price, 1)
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'parts_shop',
        title = locale('parts_shop'),
        options = options
    })
    
    lib.showContext('parts_shop')
end

function Inventory.PurchaseItem(item, price, quantity)
    local input = lib.inputDialog(locale('purchase_item'), {
        {
            type = 'number',
            label = locale('quantity'),
            default = quantity,
            min = 1,
            max = 10,
            required = true
        }
    })
    
    if input then
        local totalPrice = price * input[1]
        
        lib.callback('mechanic:server:purchasePart', false, function(success)
            if success then
                lib.notify({
                    title = locale('purchase_successful'),
                    description = locale('item_purchased', input[1], item),
                    type = 'success'
                })
            else
                lib.notify({
                    title = locale('purchase_failed'),
                    description = locale('insufficient_funds'),
                    type = 'error'
                })
            end
        end, item, input[1], totalPrice)
    end
end

function Inventory.ManageStock(shopId)
    local stockData = lib.callback.await('mechanic:server:getShopStock', false, shopId)
    
    if not stockData then return end
    
    local options = {}
    
    for item, data in pairs(stockData) do
        local statusColor = data.quantity > 10 and '#2ecc71' or data.quantity > 5 and '#f39c12' or '#e74c3c'
        
        table.insert(options, {
            title = data.label,
            description = locale('in_stock', data.quantity),
            icon = 'fas fa-box',
            iconColor = statusColor,
            progress = math.min(data.quantity, 100),
            colorScheme = data.quantity > 10 and 'green' or data.quantity > 5 and 'orange' or 'red',
            metadata = {
                {label = locale('price'), value = '$' .. data.price},
                {label = locale('supplier_cost'), value = '$' .. math.floor(data.price * 0.6)}
            },
            onSelect = function()
                Inventory.RestockItem(shopId, item, data)
            end
        })
    end
    
    lib.registerContext({
        id = 'stock_management',
        title = locale('stock_management'),
        options = options
    })
    
    lib.showContext('stock_management')
end

function Inventory.RestockItem(shopId, item, itemData)
    local input = lib.inputDialog(locale('restock_item'), {
        {
            type = 'number',
            label = locale('quantity_to_order'),
            description = locale('supplier_cost_per_unit', math.floor(itemData.price * 0.6)),
            default = 10,
            min = 1,
            max = 100,
            required = true
        }
    })
    
    if input then
        local totalCost = math.floor(itemData.price * 0.6 * input[1])
        
        lib.callback('mechanic:server:restockItem', false, function(success)
            if success then
                lib.notify({
                    title = locale('order_placed'),
                    description = locale('items_ordered', input[1], itemData.label),
                    type = 'success'
                })
                
                -- Refresh stock menu
                Inventory.ManageStock(shopId)
            else
                lib.notify({
                    title = locale('order_failed'),
                    description = locale('insufficient_shop_funds'),
                    type = 'error'
                })
            end
        end, shopId, item, input[1], totalCost)
    end
end

function Inventory.CreateStockZone(shop)
    if not shop.zones.storage then return end
    
    local stockZone = lib.points.new({
        coords = shop.zones.storage,
        distance = 5,
        shop = shop
    })
    
    function stockZone:nearby()
        if self.currentDistance < 2.0 then
            lib.showTextUI(locale('press_to_access_storage'))
            
            if IsControlJustPressed(0, 38) then
                Inventory.OpenShopInventory(self.shop.id)
            end
        end
    end
    
    function stockZone:onExit()
        lib.hideTextUI()
    end
    
    return stockZone
end

return Inventory

local Billing = {}

local currentInvoice = {
    items = {},
    labor = 0,
    parts = 0,
    total = 0,
    targetPlayer = nil
}

function Billing.CreateInvoice(targetPlayerId)
    currentInvoice = {
        items = {},
        labor = 0,
        parts = 0,
        total = 0,
        targetPlayer = targetPlayerId
    }
    
    Billing.OpenInvoiceMenu()
end

function Billing.OpenInvoiceMenu()
    local options = {}
    
    -- Add current items
    for _, item in ipairs(currentInvoice.items) do
        table.insert(options, {
            title = item.label,
            description = locale('quantity_x', item.quantity),
            icon = item.type == 'labor' and 'fas fa-wrench' or 'fas fa-box',
            iconColor = item.type == 'labor' and '#3498db' or '#e74c3c',
            metadata = {
                {label = locale('price'), value = '$' .. item.price},
                {label = locale('total'), value = '$' .. (item.price * item.quantity)}
            },
            disabled = true
        })
    end
    
    -- Add new item options
    table.insert(options, {
        title = locale('add_labor'),
        description = locale('add_labor_desc'),
        icon = 'fas fa-plus-circle',
        iconColor = '#51cf66',
        onSelect = function()
            Billing.AddLaborDialog()
        end
    })
    
    table.insert(options, {
        title = locale('add_part'),
        description = locale('add_part_desc'),
        icon = 'fas fa-plus-circle',
        iconColor = '#51cf66',
        onSelect = function()
            Billing.AddPartDialog()
        end
    })
    
    -- Totals
    table.insert(options, {
        title = locale('invoice_total'),
        description = locale('labor_parts', currentInvoice.labor, currentInvoice.parts),
        icon = 'fas fa-calculator',
        progress = 100,
        colorScheme = 'green',
        metadata = {
            {label = locale('total'), value = '$' .. currentInvoice.total}
        },
        disabled = true
    })
    
    -- Send invoice
    table.insert(options, {
        title = locale('send_invoice'),
        description = locale('send_to_customer'),
        icon = 'fas fa-paper-plane',
        iconColor = '#3498db',
        disabled = currentInvoice.total == 0,
        onSelect = function()
            Billing.SendInvoice()
        end
    })
    
    lib.registerContext({
        id = 'invoice_menu',
        title = locale('create_invoice'),
        options = options
    })
    
    lib.showContext('invoice_menu')
end

function Billing.AddLaborDialog()
    local input = lib.inputDialog(locale('add_labor'), {
        {
            type = 'input',
            label = locale('description'),
            required = true
        },
        {
            type = 'number',
            label = locale('hours'),
            default = 1,
            min = 0.5,
            max = 10,
            step = 0.5,
            required = true
        },
        {
            type = 'number',
            label = locale('hourly_rate'),
            default = 50,
            min = 25,
            max = 150,
            required = true
        }
    })
    
    if input then
        local laborItem = {
            type = 'labor',
            label = input[1],
            quantity = input[2],
            price = input[3],
            total = input[2] * input[3]
        }
        
        table.insert(currentInvoice.items, laborItem)
        currentInvoice.labor = currentInvoice.labor + laborItem.total
        currentInvoice.total = currentInvoice.labor + currentInvoice.parts
        
        lib.notify({
            title = locale('labor_added'),
            type = 'success'
        })
        
        Billing.OpenInvoiceMenu()
    end
end

function Billing.AddPartDialog()
    local partOptions = {}

    for key, item in pairs(Config.MaintenanceItems) do
        local unitPrice = math.floor((item.price or 100) * Config.Economy.partMarkup)
        table.insert(partOptions, {
            label = item.label,
            value = ('maintenance:%s'):format(key),
            description = locale('price_format', unitPrice)
        })
    end

    for key, part in pairs(Config.VehicleParts) do
        local unitPrice = math.floor(part.price * Config.Economy.partMarkup)
        table.insert(partOptions, {
            label = part.label,
            value = ('part:%s'):format(key),
            description = locale('price_format', unitPrice)
        })
    end

    table.sort(partOptions, function(a, b)
        return a.label < b.label
    end)

    local input = lib.inputDialog(locale('add_part'), {
        {
            type = 'select',
            label = locale('part_type'),
            options = partOptions,
            required = true
        },
        {
            type = 'number',
            label = locale('quantity'),
            default = 1,
            min = 1,
            max = 10,
            required = true
        }
    })

    if not input then return end

    local selection = input[1]
    local quantity = input[2]
    local category, key = selection:match('([^:]+):(.+)')

    if not category or not key then
        lib.notify({
            title = locale('invalid_item'),
            type = 'error'
        })
        return
    end

    local partConfig
    local unitPrice

    if category == 'maintenance' then
        partConfig = Config.MaintenanceItems[key]
        if not partConfig then
            lib.notify({
                title = locale('invalid_item'),
                type = 'error'
            })
            return
        end

        unitPrice = math.floor((partConfig.price or 100) * Config.Economy.partMarkup)
    else
        partConfig = Config.VehicleParts[key]
        if not partConfig then
            lib.notify({
                title = locale('invalid_item'),
                type = 'error'
            })
            return
        end

        unitPrice = math.floor(partConfig.price * Config.Economy.partMarkup)
    end

    local partItem = {
        type = 'part',
        label = partConfig.label,
        quantity = quantity,
        price = unitPrice,
        total = unitPrice * quantity
    }

    table.insert(currentInvoice.items, partItem)
    currentInvoice.parts = currentInvoice.parts + partItem.total
    currentInvoice.total = currentInvoice.labor + currentInvoice.parts

    lib.notify({
        title = locale('part_added'),
        type = 'success'
    })

    Billing.OpenInvoiceMenu()
end

function Billing.SendInvoice()
    if currentInvoice.total == 0 then
        lib.notify({
            title = locale('invoice_empty'),
            type = 'error'
        })
        return
    end
    
    lib.callback('mechanic:server:sendInvoice', false, function(success)
        if success then
            lib.notify({
                title = locale('invoice_sent'),
                type = 'success'
            })
            
            -- Reset invoice
            currentInvoice = {
                items = {},
                labor = 0,
                parts = 0,
                total = 0,
                targetPlayer = nil
            }
        else
            lib.notify({
                title = locale('invoice_failed'),
                type = 'error'
            })
        end
    end, currentInvoice)
end

function Billing.QuickBill(targetPlayerId, amount, reason)
    lib.callback('mechanic:server:sendQuickBill', false, function(success)
        if success then
            lib.notify({
                title = locale('bill_sent'),
                type = 'success'
            })
        else
            lib.notify({
                title = locale('bill_failed'),
                type = 'error'
            })
        end
    end, targetPlayerId, amount, reason)
end

return Billing

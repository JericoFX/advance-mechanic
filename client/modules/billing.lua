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
    local input = lib.inputDialog(locale('add_part'), {
        {
            type = 'select',
            label = locale('part_type'),
            options = {
                {label = locale('engine_oil'), value = 'engine_oil'},
                {label = locale('brake_fluid'), value = 'brake_fluid'},
                {label = locale('coolant'), value = 'coolant'},
                {label = locale('car_battery'), value = 'car_battery'},
                {label = locale('car_door'), value = 'car_door'},
                {label = locale('car_hood'), value = 'car_hood'},
                {label = locale('car_trunk'), value = 'car_trunk'},
                {label = locale('car_wheel'), value = 'car_wheel'},
                {label = locale('car_window'), value = 'car_window'},
                {label = locale('car_bumper'), value = 'car_bumper'}
            },
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
    
    if input then
        local partConfig = Config.VehicleParts[input[1]] or Config.MaintenanceItems[input[1]]
        if partConfig then
            local partItem = {
                type = 'part',
                label = partConfig.label,
                quantity = input[2],
                price = partConfig.price * Config.Economy.partMarkup,
                total = (partConfig.price * Config.Economy.partMarkup) * input[2]
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
    end
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

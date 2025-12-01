local Billing = {}
local Framework = require 'shared.framework'

lib.callback.register('mechanic:server:sendInvoice', function(source, invoice)
    local src = source
    local Player = Framework.GetPlayer(src)
    local Target = Framework.GetPlayer(invoice.targetPlayer)
    
    if not Player or not Target then return false end
    
    if Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    -- Create detailed invoice description
    local description = 'Mechanic Invoice\n'
    for _, item in ipairs(invoice.items) do
        description = description .. string.format('%s x%d - $%d\n', item.label, item.quantity, item.total)
    end
    description = description .. string.format('\nTotal: $%d', invoice.total)
    
    -- Send bill using QBCore billing system
    MySQL.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)', {
        Target.PlayerData.citizenid,
        invoice.total,
        Config.JobName,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        Player.PlayerData.citizenid
    })
    
    -- Notify both players
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Invoice Sent',
        description = string.format('Invoice for $%d sent successfully', invoice.total),
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', invoice.targetPlayer, {
        title = 'Invoice Received',
        description = string.format('You received a mechanic invoice for $%d', invoice.total),
        type = 'info'
    })
    
    return true
end)

lib.callback.register('mechanic:server:sendQuickBill', function(source, targetId, amount, reason)
    local src = source
    local Player = Framework.GetPlayer(src)
    local Target = Framework.GetPlayer(targetId)
    
    if not Player or not Target then return false end
    
    if Player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    MySQL.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)', {
        Target.PlayerData.citizenid,
        amount,
        Config.JobName,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        Player.PlayerData.citizenid
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Bill Sent',
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Bill Received',
        description = reason,
        type = 'info'
    })
    
    return true
end)

return Billing

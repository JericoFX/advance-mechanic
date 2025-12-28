local Billing = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

local function isPlayerNearTarget(source, targetId, maxDistance)
    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetId)
    if not sourcePed or not targetPed then return false end
    if not DoesEntityExist(sourcePed) or not DoesEntityExist(targetPed) then return false end
    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    return #(sourceCoords - targetCoords) <= (maxDistance or 5.0)
end

lib.callback.register('mechanic:server:sendInvoice', function(source, invoice)
    local src = source
    local Player = Framework.GetPlayer(src)
    local normalized = Validation.NormalizeInvoice(invoice)
    
    if not Player or not normalized then return false end
    
    if not Validation.IsMechanic(Player) then
        return false
    end

    local Target = Framework.GetPlayer(normalized.targetPlayer)
    if not Target then return false end

    if not Validation.CheckRateLimit(src, 'billing_invoice', Config.Security.rateLimits.billingMs) then
        return false
    end

    if not isPlayerNearTarget(src, normalized.targetPlayer, Config.Billing.maxDistance) then
        return false
    end
    
    -- Create detailed invoice description
    local description = 'Mechanic Invoice\n'
    for _, item in ipairs(normalized.items) do
        description = description .. string.format('%s x%d - $%d\n', item.label, item.quantity, item.total)
    end
    description = description .. string.format('\nTotal: $%d', normalized.total)
    
    -- Send bill using QBCore billing system
    if Framework.IsQBCore then
        MySQL.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)', {
            Target.PlayerData.citizenid,
            normalized.total,
            Config.JobName,
            Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            Player.PlayerData.citizenid
        })
    else
        -- TODO: add ESX billing integration.
        return false
    end
    
    -- Notify both players
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Invoice Sent',
        description = string.format('Invoice for $%d sent successfully', normalized.total),
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', normalized.targetPlayer, {
        title = 'Invoice Received',
        description = string.format('You received a mechanic invoice for $%d', normalized.total),
        type = 'info'
    })
    
    return true
end)

lib.callback.register('mechanic:server:sendQuickBill', function(source, targetId, amount, reason)
    local src = source
    local Player = Framework.GetPlayer(src)
    local Target = Framework.GetPlayer(targetId)
    
    if not Player or not Target then return false end
    
    if not Validation.IsMechanic(Player) then
        return false
    end

    if not Validation.CheckRateLimit(src, 'billing_quick', Config.Security.rateLimits.billingMs) then
        return false
    end

    if not isPlayerNearTarget(src, targetId, Config.Billing.maxDistance) then
        return false
    end

    local billAmount = tonumber(amount)
    if not Validation.IsNumberInRange(billAmount, Config.Billing.quickBill.minAmount, Config.Billing.quickBill.maxAmount) then
        return false
    end
    
    if Framework.IsQBCore then
        MySQL.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)', {
            Target.PlayerData.citizenid,
            billAmount,
            Config.JobName,
            Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            Player.PlayerData.citizenid
        })
    else
        -- TODO: add ESX billing integration.
        return false
    end
    
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

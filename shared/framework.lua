local Framework = {}

Framework.IsServer = IsDuplicityVersion()
Framework.IsQBCore = Config.Framework.core == 'QBCore'
Framework.IsESX = Config.Framework.core == 'ESX'

local function getCore()
    if Framework.IsQBCore then
        return exports[Config.Framework.resourceName]:GetCoreObject()
    end

    if Framework.IsESX then
        local esx = exports[Config.Framework.resourceName]:getSharedObject()
        return esx
    end

    return nil
end

Framework.Core = getCore()

local function buildCharInfo(name, data)
    local firstname = data and (data.firstname or data.firstName)
    local lastname = data and (data.lastname or data.lastName)

    if firstname or lastname then
        return {
            firstname = firstname or '',
            lastname = lastname or ''
        }
    end

    if not name then
        return { firstname = '', lastname = '' }
    end

    local first, last = name:match('^(%S+)%s+(.*)$')
    return {
        firstname = first or name,
        lastname = last or ''
    }
end

local function wrapESXPlayer(xPlayer)
    if not xPlayer then return nil end

    local job = xPlayer.getJob and xPlayer.getJob() or {}
    local identifier = (xPlayer.getIdentifier and xPlayer.getIdentifier()) or xPlayer.identifier
    local accounts = xPlayer.getAccount and xPlayer.getAccount('bank') or nil
    local name = xPlayer.getName and xPlayer.getName() or nil
    local cash = xPlayer.getMoney and xPlayer.getMoney() or 0
    local bank = accounts and accounts.money or 0
    local charinfo = buildCharInfo(name, xPlayer.get and xPlayer.get('firstName') and {
        firstname = xPlayer.get('firstName'),
        lastname = xPlayer.get('lastName')
    })

    local playerWrapper = {
        source = xPlayer.source,
        identifier = identifier,
        PlayerData = {
            source = xPlayer.source,
            citizenid = identifier,
            job = {name = job.name or job.label or ''},
            charinfo = charinfo,
            money = {
                cash = cash,
                bank = bank
            }
        },
        Functions = {}
    }

    function playerWrapper.Functions.RemoveMoney(account, amount)
        if account == 'bank' then
            local bankAccount = xPlayer.getAccount and xPlayer.getAccount('bank') or accounts
            if bankAccount and bankAccount.money and bankAccount.money >= amount then
                xPlayer.removeAccountMoney('bank', amount)
                return true
            end
            return false
        end

        if xPlayer.getMoney and xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount)
            return true
        end

        return false
    end

    function playerWrapper.Functions.AddMoney(account, amount)
        if account == 'bank' then
            if xPlayer.addAccountMoney then
                xPlayer.addAccountMoney('bank', amount)
            end
            return true
        end

        if xPlayer.addMoney then
            xPlayer.addMoney(amount)
            return true
        end

        return false
    end

    function playerWrapper.Functions.SetJob(job, grade)
        if xPlayer.setJob then
            xPlayer.setJob(job, grade)
        end
    end

    return playerWrapper
end

function Framework.GetPlayer(source)
    if Framework.IsQBCore then
        return Framework.Core.Functions.GetPlayer(source)
    end

    if Framework.IsESX then
        local xPlayer = Framework.Core.GetPlayerFromId(source)
        return wrapESXPlayer(xPlayer)
    end

    return nil
end

function Framework.GetPlayerByCitizenId(citizenId)
    if Framework.IsQBCore then
        return Framework.Core.Functions.GetPlayerByCitizenId(citizenId)
    end

    if Framework.IsESX then
        for _, playerId in ipairs(Framework.Core.GetPlayers()) do
            local xPlayer = Framework.Core.GetPlayerFromId(playerId)
            local identifier = xPlayer and ((xPlayer.getIdentifier and xPlayer.getIdentifier()) or xPlayer.identifier)
            if identifier == citizenId then
                return wrapESXPlayer(xPlayer)
            end
        end
    end

    return nil
end

function Framework.CreateCallback(name, cb)
    if Framework.IsQBCore then
        return Framework.Core.Functions.CreateCallback(name, cb)
    end

    if Framework.IsESX and Framework.Core.RegisterServerCallback then
        return Framework.Core.RegisterServerCallback(name, cb)
    end
end

function Framework.HasPermission(source, permission)
    if Framework.IsQBCore then
        return Framework.Core.Functions.HasPermission(source, permission)
    end

    if Framework.IsESX then
        local xPlayer = Framework.Core.GetPlayerFromId(source)
        if not xPlayer then return false end

        if xPlayer.getGroup then
            local group = xPlayer.getGroup()
            return group == permission or group == 'superadmin'
        end

        return IsPlayerAceAllowed(source, ('group.%s'):format(permission))
    end

    return false
end

function Framework.GetPlayerData()
    if Framework.IsServer then
        return nil
    end

    if Framework.IsQBCore then
        return Framework.Core.Functions.GetPlayerData()
    end

    if Framework.IsESX then
        local data = Framework.Core.GetPlayerData()
        if not data then return nil end
        data.job = data.job or {}
        local accounts = data.accounts or {}
        local cash = (data.money and data.money.cash) or data.cash or 0
        local bank = 0

        if accounts["bank"] and accounts["bank"].money then
            bank = accounts["bank"].money
        elseif data.bank ~= nil then
            bank = data.bank
        elseif data.money and data.money.bank then
            bank = data.money.bank
        end

        data.money = { cash = cash, bank = bank }
        data.citizenid = data.identifier or data.citizenid
        data.charinfo = buildCharInfo(data.name, data)
        return data
    end

    return nil
end

function Framework.OnPlayerLoaded(handler)
    if Framework.IsServer then return end

    if Framework.IsQBCore then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            handler(Framework.GetPlayerData())
        end)
    elseif Framework.IsESX then
        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            handler(Framework.GetPlayerData() or xPlayer)
        end)
    end
end

function Framework.OnPlayerUnload(handler)
    if Framework.IsServer then return end

    if Framework.IsQBCore then
        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            handler()
        end)
    elseif Framework.IsESX then
        RegisterNetEvent('esx:onPlayerLogout', function()
            handler()
        end)
    end
end

return Framework

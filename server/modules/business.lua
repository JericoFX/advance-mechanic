local Business = {}

-- Crear negocio mecánico
function Business.createBusiness(shopId, ownerId, shopName)
    local success, businessId = exports['advance-manager']:createBusiness(
        shopName,
        ownerId,
        'mechanic',
        Config.ShopCreation.basePrice,
        {
            shop_id = shopId,
            type = 'mechanic_shop'
        }
    )
    
    return success, businessId
end

-- Obtener negocio por tienda
function Business.getBusinessByShop(shopId)
    local businesses = exports['advance-manager']:getBusinessByOwner(shopId)
    if businesses and #businesses > 0 then
        for _, business in pairs(businesses) do
            if business.metadata and business.metadata.shop_id == shopId then
                return business
            end
        end
    end
    return nil
end

-- Verificar si es jefe del negocio
function Business.isBusinessBoss(citizenId, shopId)
    local business = Business.getBusinessByShop(shopId)
    if not business then return false end
    
    return exports['advance-manager']:isBusinessBoss(citizenId, business.id)
end

-- Verificar permisos del negocio
function Business.hasBusinessPermission(citizenId, shopId, permission)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return false end
    
    return exports['advance-manager']:hasBusinessPermission(citizenId, businessData.id, permission)
end

-- Obtener fondos del negocio
function Business.getBusinessFunds(shopId)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return 0 end
    
    return exports['advance-manager']:getBusinessFunds(businessData.id)
end

-- Actualizar fondos del negocio
function Business.updateBusinessFunds(shopId, amount, isWithdrawal)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return false end
    
    return exports['advance-manager']:updateBusinessFunds(businessData.id, amount, isWithdrawal)
end

-- Obtener empleados del negocio
function Business.getBusinessEmployees(shopId)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return {} end
    
    local employees = {}
    local result = MySQL.query.await([[
        SELECT be.*, p.charinfo
        FROM business_employees be
        LEFT JOIN players p ON p.citizenid = be.citizenid
        WHERE be.business_id = ?
    ]], {businessData.id})
    
    if result then
        for _, employee in pairs(result) do
            local charinfo = json.decode(employee.charinfo or '{}')
            table.insert(employees, {
                citizenid = employee.citizenid,
                grade = employee.grade,
                wage = employee.wage,
                name = charinfo.firstname .. ' ' .. charinfo.lastname,
                hired_at = employee.hired_at,
                on_duty = employee.on_duty or false,
                total_hours = employee.total_hours or 0
            })
        end
    end
    
    return employees
end

-- Contratar empleado
function Business.hireEmployee(shopId, targetId, grade)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return false, 'business_not_found' end
    
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then return false, 'player_not_found' end
    
    local targetCitizenId = Target.PlayerData.citizenid
    
    -- Usar advance-manager para contratar empleado
    local success, message = lib.callback.await('advance-manager:hireEmployee', false, businessData.id, targetId, grade, Config.Employees.defaultWage)
    
    if success then
        -- Actualizar job del jugador
        Target.Functions.SetJob(Config.JobName, grade)
        return true
    else
        return false, message
    end
end

-- Despedir empleado
function Business.fireEmployee(shopId, targetCitizenId)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return false, 'business_not_found' end
    
    local success = lib.callback.await('advance-manager:fireEmployee', false, businessData.id, targetCitizenId)
    
    if success then
        -- Actualizar job del jugador
        local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
        if Target then
            Target.Functions.SetJob('unemployed', 0)
        end
        return true
    else
        return false, 'fire_failed'
    end
end

-- Actualizar grado del empleado
function Business.updateEmployeeGrade(shopId, targetCitizenId, newGrade)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return false, 'business_not_found' end
    
    local success = lib.callback.await('advance-manager:updateEmployeeGrade', false, businessData.id, targetCitizenId, newGrade)
    
    if success then
        -- Actualizar job del jugador
        local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
        if Target then
            Target.Functions.SetJob(Config.JobName, newGrade)
        end
        return true
    else
        return false, 'grade_update_failed'
    end
end

-- Actualizar wage del empleado
function Business.updateEmployeeWage(shopId, targetCitizenId, newWage)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return false, 'business_not_found' end
    
    local success = lib.callback.await('advance-manager:updateEmployeeWage', false, businessData.id, targetCitizenId, newWage)
    
    if success then
        return true
    else
        return false, 'wage_update_failed'
    end
end

-- Obtener rank del empleado
function Business.getEmployeeRank(citizenId, shopId)
    local businessData = Business.getBusinessByShop(shopId)
    if not businessData then return 0 end
    
    -- Verificar si es el dueño del negocio
    if businessData.owner == citizenId then
        return Config.BossGrade
    end
    
    -- Verificar si es boss del negocio
    if exports['advance-manager']:isBusinessBoss(citizenId, businessData.id) then
        return Config.BossGrade
    end
    
    -- Obtener el grade del empleado
    local result = MySQL.query.await([[
        SELECT grade FROM business_employees 
        WHERE business_id = ? AND citizenid = ?
    ]], {businessData.id, citizenId})
    
    if result and result[1] then
        return result[1].grade
    end
    
    return 0
end

return Business

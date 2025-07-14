local Employees = {}

function Employees.OpenManagementMenu(shop)
    local playerData = QBCore.Functions.GetPlayerData()
    
    if not shop.owner or shop.owner ~= playerData.citizenid then
        if playerData.job.grade < Config.BossGrade then
            lib.notify({
                title = locale('not_shop_owner'),
                type = 'error'
            })
            return
        end
    end
    
    local employees = lib.callback.await('mechanic:server:getEmployees', false, shop.id)
    
    local options = {
        {
            title = locale('hire_employee'),
            description = locale('hire_new_employee'),
            icon = 'fas fa-user-plus',
            iconColor = '#2ecc71',
            onSelect = function()
                Employees.ShowHireMenu(shop)
            end
        }
    }
    
    if employees and #employees > 0 then
        table.insert(options, {
            title = locale('employee_list'),
            description = locale('manage_current_employees'),
            icon = 'fas fa-users',
            iconColor = '#3498db',
            arrow = true,
            onSelect = function()
                Employees.ShowEmployeeList(shop, employees)
            end
        })
        
        table.insert(options, {
            title = locale('schedule_management'),
            description = locale('manage_work_schedules'),
            icon = 'fas fa-calendar-alt',
            iconColor = '#9b59b6',
            arrow = true,
            onSelect = function()
                Employees.ShowScheduleMenu(shop)
            end
        })
    end
    
    table.insert(options, {
        title = locale('payroll_settings'),
        description = locale('configure_automatic_payments'),
        icon = 'fas fa-money-bill-wave',
        iconColor = '#f39c12',
        arrow = true,
        onSelect = function()
            Employees.ShowPayrollMenu(shop)
        end
    })
    
    lib.registerContext({
        id = 'employee_management',
        title = locale('manage_employees'),
        options = options
    })
    
    lib.showContext('employee_management')
end

function Employees.ShowHireMenu(shop)
    local input = lib.inputDialog(locale('hire_employee'), {
        {
            type = 'input',
            label = locale('player_id'),
            description = locale('enter_player_id'),
            required = true
        },
        {
            type = 'select',
            label = locale('employee_grade'),
            options = {
                {label = locale('trainee'), value = 0},
                {label = locale('mechanic'), value = 1},
                {label = locale('senior_mechanic'), value = 2},
                {label = locale('supervisor'), value = 3}
            },
            required = true
        },
        {
            type = 'number',
            label = locale('hourly_wage'),
            default = Config.Employees.defaultWage,
            min = Config.Employees.minWage,
            max = Config.Employees.maxWage,
            required = true
        }
    })
    
    if input then
        local targetId = tonumber(input[1])
        local grade = input[2]
        local wage = input[3]
        
        lib.callback('mechanic:server:hireEmployee', false, function(success, message)
            if success then
                lib.notify({
                    title = locale('employee_hired'),
                    description = message,
                    type = 'success'
                })
                Employees.OpenManagementMenu(shop)
            else
                lib.notify({
                    title = locale('hire_failed'),
                    description = message,
                    type = 'error'
                })
            end
        end, shop.id, targetId, grade, wage)
    end
end

function Employees.ShowEmployeeList(shop, employees)
    local options = {}
    
    for _, employee in ipairs(employees) do
        local gradeLabel = Employees.GetGradeLabel(employee.grade)
        local statusIcon = employee.on_duty and 'fas fa-circle' or 'fas fa-circle'
        local statusColor = employee.on_duty and '#2ecc71' or '#e74c3c'
        
        table.insert(options, {
            title = employee.name or locale('unknown_player'),
            description = string.format('%s - %s', gradeLabel, locale('hourly_wage_format', employee.wage)),
            icon = statusIcon,
            iconColor = statusColor,
            metadata = {
                {label = locale('employee_id'), value = employee.citizenid},
                {label = locale('hire_date'), value = employee.hired_at},
                {label = locale('status'), value = employee.on_duty and locale('on_duty') or locale('off_duty')},
                {label = locale('total_hours'), value = employee.total_hours or 0}
            },
            onSelect = function()
                Employees.ShowEmployeeDetails(shop, employee)
            end
        })
    end
    
    lib.registerContext({
        id = 'employee_list',
        title = locale('employee_list'),
        menu = 'employee_management',
        options = options
    })
    
    lib.showContext('employee_list')
end

function Employees.ShowEmployeeDetails(shop, employee)
    local gradeLabel = Employees.GetGradeLabel(employee.grade)
    
    local options = {
        {
            title = locale('employee_info'),
            description = string.format('%s - %s', employee.name, gradeLabel),
            icon = 'fas fa-id-card',
            disabled = true,
            metadata = {
                {label = locale('employee_grade'), value = gradeLabel},
                {label = locale('hourly_wage'), value = '$' .. employee.wage},
                {label = locale('total_hours'), value = employee.total_hours or 0},
                {label = locale('hire_date'), value = employee.hired_at}
            }
        },
        {
            title = locale('change_grade'),
            description = locale('modify_employee_grade'),
            icon = 'fas fa-user-edit',
            iconColor = '#3498db',
            onSelect = function()
                Employees.ShowGradeChangeMenu(shop, employee)
            end
        },
        {
            title = locale('change_wage'),
            description = locale('modify_employee_wage'),
            icon = 'fas fa-money-bill',
            iconColor = '#f39c12',
            onSelect = function()
                Employees.ShowWageChangeMenu(shop, employee)
            end
        },
        {
            title = locale('fire_employee'),
            description = locale('remove_employee_from_shop'),
            icon = 'fas fa-user-times',
            iconColor = '#e74c3c',
            onSelect = function()
                Employees.ShowFireConfirmation(shop, employee)
            end
        }
    }
    
    lib.registerContext({
        id = 'employee_details',
        title = employee.name or locale('employee_details'),
        menu = 'employee_list',
        options = options
    })
    
    lib.showContext('employee_details')
end

function Employees.ShowGradeChangeMenu(shop, employee)
    local input = lib.inputDialog(locale('change_grade'), {
        {
            type = 'select',
            label = locale('new_grade'),
            options = {
                {label = locale('trainee'), value = 0},
                {label = locale('mechanic'), value = 1},
                {label = locale('senior_mechanic'), value = 2},
                {label = locale('supervisor'), value = 3}
            },
            default = employee.grade,
            required = true
        }
    })
    
    if input then
        lib.callback('mechanic:server:changeEmployeeGrade', false, function(success, message)
            if success then
                lib.notify({
                    title = locale('grade_changed'),
                    description = message,
                    type = 'success'
                })
                Employees.OpenManagementMenu(shop)
            else
                lib.notify({
                    title = locale('change_failed'),
                    description = message,
                    type = 'error'
                })
            end
        end, shop.id, employee.citizenid, input[1])
    end
end

function Employees.ShowWageChangeMenu(shop, employee)
    local input = lib.inputDialog(locale('change_wage'), {
        {
            type = 'number',
            label = locale('new_hourly_wage'),
            default = employee.wage,
            min = Config.Employees.minWage,
            max = Config.Employees.maxWage,
            required = true
        }
    })
    
    if input then
        lib.callback('mechanic:server:changeEmployeeWage', false, function(success, message)
            if success then
                lib.notify({
                    title = locale('wage_changed'),
                    description = message,
                    type = 'success'
                })
                Employees.OpenManagementMenu(shop)
            else
                lib.notify({
                    title = locale('change_failed'),
                    description = message,
                    type = 'error'
                })
            end
        end, shop.id, employee.citizenid, input[1])
    end
end

function Employees.ShowFireConfirmation(shop, employee)
    local alert = lib.alertDialog({
        header = locale('fire_employee'),
        content = locale('fire_confirmation', employee.name or locale('employee')),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        lib.callback('mechanic:server:fireEmployee', false, function(success, message)
            if success then
                lib.notify({
                    title = locale('employee_fired'),
                    description = message,
                    type = 'success'
                })
                Employees.OpenManagementMenu(shop)
            else
                lib.notify({
                    title = locale('fire_failed'),
                    description = message,
                    type = 'error'
                })
            end
        end, shop.id, employee.citizenid)
    end
end

function Employees.ShowScheduleMenu(shop)
    local options = {
        {
            title = locale('view_schedules'),
            description = locale('view_all_employee_schedules'),
            icon = 'fas fa-calendar',
            iconColor = '#3498db',
            onSelect = function()
                Employees.ShowAllSchedules(shop)
            end
        },
        {
            title = locale('create_schedule'),
            description = locale('create_new_work_schedule'),
            icon = 'fas fa-plus-circle',
            iconColor = '#2ecc71',
            onSelect = function()
                Employees.ShowCreateScheduleMenu(shop)
            end
        },
        {
            title = locale('schedule_templates'),
            description = locale('manage_schedule_templates'),
            icon = 'fas fa-copy',
            iconColor = '#9b59b6',
            onSelect = function()
                Employees.ShowScheduleTemplates(shop)
            end
        }
    }
    
    lib.registerContext({
        id = 'schedule_management',
        title = locale('schedule_management'),
        menu = 'employee_management',
        options = options
    })
    
    lib.showContext('schedule_management')
end

function Employees.ShowPayrollMenu(shop)
    local payrollSettings = lib.callback.await('mechanic:server:getPayrollSettings', false, shop.id)
    
    local options = {
        {
            title = locale('payroll_status'),
            description = payrollSettings.enabled and locale('payroll_enabled') or locale('payroll_disabled'),
            icon = payrollSettings.enabled and 'fas fa-toggle-on' or 'fas fa-toggle-off',
            iconColor = payrollSettings.enabled and '#2ecc71' or '#e74c3c',
            disabled = true
        },
        {
            title = locale('toggle_payroll'),
            description = locale('enable_disable_automatic_payroll'),
            icon = 'fas fa-power-off',
            iconColor = '#f39c12',
            onSelect = function()
                Employees.TogglePayroll(shop)
            end
        },
        {
            title = locale('payment_frequency'),
            description = locale('current_frequency', payrollSettings.frequency or 'weekly'),
            icon = 'fas fa-clock',
            iconColor = '#3498db',
            onSelect = function()
                Employees.ShowFrequencyMenu(shop)
            end
        },
        {
            title = locale('payment_day'),
            description = locale('current_payment_day', payrollSettings.payment_day or 'friday'),
            icon = 'fas fa-calendar-day',
            iconColor = '#9b59b6',
            onSelect = function()
                Employees.ShowPaymentDayMenu(shop)
            end
        }
    }
    
    lib.registerContext({
        id = 'payroll_settings',
        title = locale('payroll_settings'),
        menu = 'employee_management',
        options = options
    })
    
    lib.showContext('payroll_settings')
end

function Employees.GetGradeLabel(grade)
    local grades = {
        [0] = locale('trainee'),
        [1] = locale('mechanic'),
        [2] = locale('senior_mechanic'),
        [3] = locale('supervisor'),
        [4] = locale('manager')
    }
    return grades[grade] or locale('unknown_grade')
end

function Employees.GetPermissions(grade)
    return Config.Employees.permissions[grade] or {}
end

function Employees.CanPerformAction(action, grade)
    local permissions = Employees.GetPermissions(grade)
    return permissions[action] == true
end

function Employees.TogglePayroll(shop)
    lib.callback('mechanic:server:togglePayroll', false, function(success, enabled)
        if success then
            lib.notify({
                title = locale('payroll_updated'),
                description = enabled and locale('payroll_enabled') or locale('payroll_disabled'),
                type = 'success'
            })
            Employees.ShowPayrollMenu(shop)
        end
    end, shop.id)
end


return Employees

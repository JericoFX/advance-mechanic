Config = {}

-- Employee management settings
Config.Employees = {
    defaultWage = 15,
    minWage = 10,
    maxWage = 30,
    permissions = {
        [0] = { editWage = false, fire = false, manage_employees = false },
        [1] = { editWage = true, fire = false, manage_employees = false },
        [2] = { editWage = true, fire = true, manage_employees = false },
        [3] = { editWage = true, fire = true, manage_employees = true }
    }
}

-- Debug mode
Config.Debug = true

-- Framework settings
Config.Framework = {
    core = 'QBCore',
    getObject = 'QBCore:GetObject',
    resourceName = 'qb-core'
}

-- Job settings
Config.JobName = 'mechanic'
Config.BossGrade = 4

-- Economy settings
Config.Economy = {
    payWithCash = true,
    sellReturnPercent = 0.75,
    inspectionPrice = 500,
    partMarkup = 1.5, -- 50% markup on parts
}

Config.Billing = {
    labor = {
        minHours = 0.5,
        maxHours = 10,
        minRate = 25,
        maxRate = 150
    },
    parts = {
        minQuantity = 1,
        maxQuantity = 10,
        fallbackMaxUnitPrice = 10000 -- TODO: adjust if custom part pricing exceeds this.
    },
    quickBill = {
        minAmount = 1,
        maxAmount = 100000    -- TODO: adjust to match economy balance.
    },
    maxInvoiceTotal = 250000, -- TODO: adjust to match economy balance.
    maxDistance = 5.0         -- TODO: adjust mechanic billing proximity requirement.
}

Config.Tuning = {
    performanceMods = {
        [11] = { maxLevel = 4, basePrice = 5000, label = 'Engine' },
        [12] = { maxLevel = 3, basePrice = 3000, label = 'Brakes' },
        [13] = { maxLevel = 3, basePrice = 4000, label = 'Transmission' },
        [15] = { maxLevel = 4, basePrice = 3500, label = 'Turbo/SC' },
        [16] = { maxLevel = 5, basePrice = 7500, label = 'Exhaust' },
        [18] = { maxLevel = 1, basePrice = 15000, label = 'Turbo Toggle' }
    },
    visualMods = {
        [0] = { basePrice = 3000 },
        [1] = { basePrice = 2500 },
        [2] = { basePrice = 2500 },
        [3] = { basePrice = 2000 },
        [4] = { basePrice = 1500 }
    },
    nitro = {
        install = {
            [50] = 5000,
            [100] = 8000
        },
        refill = 2000
    }
}

Config.Maintenance = {
    repairAllCost = 1000,
    maxComponentCost = 25000 -- TODO: adjust to match economy balance.
}

Config.Security = {
    rateLimits = {
        vehicleDeleteMs = 2000,
        vehiclePropsMs = 1500,
        vehicleDamageMs = 1500,
        fluidSyncMs = 1000,
        fluidUpdateMs = 1500,
        vehicleInspectionMs = 2000,
        vehicleFluidMs = 2000,
        vehicleColorMs = 1500,
        shopStockMs = 2000,
        spawnVehicleMs = 2000,
        createShopMs = 5000,
        missionRequestMs = 2000,
        missionCompleteMs = 2000,
        billingMs = 2000,
        diagnosticReportMs = 2000,
        repairComponentMs = 2000,
        engineSwapMs = 2000,
        engineSyncMs = 5000
    },
    diagnosticMaxDepth = 2,
    diagnosticMaxKeys = 64,
    diagnosticMaxString = 256
}

-- Shop creation settings
Config.ShopCreation = {
    basePrice = 100000,
    maxLifts = 4,
    requiresAdmin = true,
    requiredZones = {
        management = { label = 'Management Point', icon = 'fas fa-briefcase' },
        storage = { label = 'Storage Area', icon = 'fas fa-warehouse' },
        inspection = { label = 'Inspection Area', icon = 'fas fa-search' },
        garage = { label = 'Service Vehicle Garage', icon = 'fas fa-garage' },
        paint = { label = 'Paint Booth', icon = 'fas fa-spray-can' },
        parts = { label = 'Parts Shop', icon = 'fas fa-shopping-cart' },
        customer = { label = 'Customer Waiting Area', icon = 'fas fa-chair' }
    },
    vehicleSpawns = {
        service = { label = 'Service Vehicles', max = 3 },
        customer = { label = 'Customer Parking', max = 5 }
    }
}

-- Vehicle damage settings
Config.VehicleDamage = {
    enabled = true,
    damageMultiplier = 1.0,
    wheelMisalignmentThreshold = 0.3, -- 30% damage causes misalignment
    engineFailureThreshold = 0.1,     -- 10% health causes engine failure
    degradePerKm = 0.001,             -- 0.1% per km
}

-- Inspection settings
Config.Inspection = {
    checkPoints = {
        engine = { label = 'Engine', degradeRate = 0.002 },
        brakes = { label = 'Brakes', degradeRate = 0.003 },
        oil = { label = 'Oil', degradeRate = 0.004 },
        battery = { label = 'Battery', degradeRate = 0.001 },
        transmission = { label = 'Transmission', degradeRate = 0.002 },
        coolant = { label = 'Coolant', degradeRate = 0.003 },
        suspension = { label = 'Suspension', degradeRate = 0.002 },
        tires = { label = 'Tires', degradeRate = 0.004 }
    },
    requiredTool = 'diagnostic_tool'
}

-- Maintenance items
Config.MaintenanceItems = {
    oil = { item = 'engine_oil', label = 'Engine Oil', restores = 100, price = 100 },
    brakefluid = { item = 'brake_fluid', label = 'Brake Fluid', restores = 100, price = 100 },
    coolant = { item = 'coolant', label = 'Coolant', restores = 100, price = 100 },
    battery = { item = 'car_battery', label = 'Car Battery', restores = 100, price = 100 }
}

-- Vehicle parts
Config.VehicleParts = {
    door = { item = 'car_door', label = 'Car Door', price = 500 },
    hood = { item = 'car_hood', label = 'Hood', price = 400 },
    trunk = { item = 'car_trunk', label = 'Trunk', price = 450 },
    wheel = { item = 'car_wheel', label = 'Wheel', price = 300 },
    window = { item = 'car_window', label = 'Window', price = 200 },
    bumper = { item = 'car_bumper', label = 'Bumper', price = 350 }
}

-- Tools required
Config.Tools = {
    basic = {
        { item = 'toolbox', label = 'Toolbox' },
        { item = 'wrench',  label = 'Wrench' }
    },
    advanced = {
        { item = 'diagnostic_tool', label = 'Diagnostic Tool' },
        { item = 'welding_torch',   label = 'Welding Torch' },
        { item = 'hydraulic_jack',  label = 'Hydraulic Jack' }
    }
}

-- Lift settings
Config.Lifts = {
    moveSpeed = 0.01, -- meters per tick
    maxHeight = 2.0,
    minHeight = 0.0
}

-- Towing/Flatbed settings
Config.Towing = {
    vehicles = {
        flatbed = {
            model = 'flatbed',
            type = 'flatbed',
            capacity = 1
        },
        towtruck = {
            model = 'towtruck',
            type = 'hook',
            hookBone = 'misc_a',
            hookOffset = vec3(0.0, -2.0, 0.5),
            winchSpeed = 0.02,
            maxCableLength = 10.0
        },
        towtruck2 = {
            model = 'towtruck2',
            type = 'boom',
            boomBone = 'misc_b',
            maxBoomAngle = 45.0
        },
        forklift = {
            model = 'forklift',
            type = 'forklift',
            liftBone = 'forks',
            maxLiftHeight = 3.0,
            liftSpeed = 0.01,
            maxCarryWeight = 2000 -- kg
        }
    },
    spawnLocations = {}, -- Will be set per shop
    towRope = 'tow_rope',
    maxTowDistance = 10.0,
    hookKey = 'E',
    winchKeys = {
        up = 'ARROW_UP',
        down = 'ARROW_DOWN'
    }
}

-- NPC missions
Config.NPCMissions = {
    enabled = true,
    cooldown = 300,               -- 5 minutes between missions
    minDuration = 30,             -- TODO: adjust to match desired mission duration validation.
    completionRadius = 10.0,      -- TODO: adjust to match mission completion proximity.
    requiredEngineHealth = 900.0, -- TODO: adjust to match repair completion requirement.
    requiredBodyHealth = 900.0,   -- TODO: adjust to match repair completion requirement.
    locations = {
        { coords = vec4(25.73, -1347.27, 29.5, 270.0),   radius = 50.0 },
        { coords = vec4(-354.37, -135.4, 39.01, 70.0),   radius = 50.0 },
        { coords = vec4(1163.34, -323.09, 69.21, 100.0), radius = 50.0 }
    },
    vehicles = {
        'sultan', 'buffalo', 'dominator', 'gauntlet', 'phoenix'
    },
    payouts = {
        inspection = { min = 100, max = 200 },
        repair = { min = 300, max = 600 },
        towing = { min = 400, max = 800 }
    }
}

-- Blip settings
Config.Blips = {
    shops = {
        sprite = 446,
        color = 5,
        scale = 0.8,
        display = 4
    },
    mission = {
        sprite = 477,
        color = 47,
        scale = 1.0,
        display = 2
    }
}

-- UI settings
Config.UI = {
    menuPosition = 'top-right',
    progressBarPosition = 'bottom',
    notificationDuration = 5000
}

-- Animations
Config.Animations = {
    inspect = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        duration = 5000
    },
    repair = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        duration = 8000
    },
    tow = {
        dict = 'mini@repair',
        anim = 'fixing_a_ped',
        duration = 3000
    }
}

Config.PaintBooth = {
    enabled = true,
    requireLift = false,
    basePrice = 500,
    maxDistance = 5.0,
    priceMultipliers = {
        standard = 1.0,
        metallic = 1.5,
        matte = 2.0,
        chrome = 3.0,
        pearlescent = 2.5
    }
}

Config.Wrapping = {
    enabled = true,
    requireLift = false,
    basePrice = 2000,
    maxDistance = 5.0,
    materials = {
        gloss = { paintType = 0, priceMultiplier = 1.0 },
        matte = { paintType = 3, priceMultiplier = 1.3 },
        satin = { paintType = 0, pearlescent = true, priceMultiplier = 1.5 },
        carbon = { paintType = 3, baseColor = 12, priceMultiplier = 2.0 }
    }
}

Config.Suspension = {
    enabled = true,
    requireLift = true,
    basePrice = 1000,
    perParameterCost = 200,
    maxPresets = 20,
    maxDistance = 5.0,
    ranges = {
        frontHeight = { min = -0.10, max = 0.10 },
        rearHeight = { min = -0.10, max = 0.10 },
        stiffness = { min = 0, max = 100 },
        frontCamber = { min = -15.0, max = 15.0 },
        rearCamber = { min = -15.0, max = 15.0 },
        frontToe = { min = -5.0, max = 5.0 },
        rearToe = { min = -5.0, max = 5.0 }
    }
}

Config.EngineSwap = {
    enabled = true,
    requireLift = true,
    maxDistance = 5.0,
    removeInstallTime = 120,
    syncInterval = 30,
    temperatureThresholds = {
        warning = 90,
        critical = 105
    },
    wearThresholds = {
        light = 30,
        moderate = 60,
        heavy = 80,
        critical = 100
    },
    misfireChance = 0.15,
    breakdownChance = 0.05
}

Config.VehicleClassDefaults = {
    [0]  = { engine = 'i4_stock',  drivetrain = 'fwd' },
    [1]  = { engine = 'i4_turbo',  drivetrain = 'fwd' },
    [2]  = { engine = 'v6_stock',  drivetrain = 'rwd' },
    [3]  = { engine = 'i4_stock',  drivetrain = 'fwd' },
    [4]  = { engine = 'v8_stock',  drivetrain = 'rwd' },
    [5]  = { engine = 'v6_turbo',  drivetrain = 'rwd' },
    [6]  = { engine = 'v6_turbo',  drivetrain = 'rwd' },
    [7]  = { engine = 'v8_ls3',    drivetrain = 'rwd' },
    [8]  = { engine = 'v8_stock',  drivetrain = 'rwd' },
    [9]  = { engine = 'v8_stock',  drivetrain = 'awd' },
    [10] = { engine = 'v6_stock',  drivetrain = 'awd' },
    [11] = { engine = 'v6_stock',  drivetrain = 'rwd' },
    [12] = { engine = 'v6_stock',  drivetrain = 'rwd' },
    [13] = { engine = 'i4_stock',  drivetrain = 'fwd' }
}

Config.Engines = {
    ['i4_stock'] = {
        name = 'Inline-4 Stock',
        type = 'i4',
        hp = 150,
        torque = 200,
        weight = 120.0,
        rpmMax = 7000,
        rpmRedline = 6500,
        fuelConsumption = 0.8,
        heatRate = 0.6,
        coolingEfficiency = 1.0,
        wearRate = 0.3,
        drivetrainCompat = { 'fwd', 'rwd', 'awd' },
        requiredParts = { 'motor_mount_i4', 'wiring_harness' },
        transmissionCompat = { '5speed', '6speed', 'cvt' },
        installTime = 180,
        price = 5000,
        torqueCurve = {
            { rpm = 1000, percent = 40 },
            { rpm = 2000, percent = 60 },
            { rpm = 3500, percent = 85 },
            { rpm = 5000, percent = 100 },
            { rpm = 6500, percent = 90 },
            { rpm = 7000, percent = 75 }
        }
    },
    ['i4_turbo'] = {
        name = 'Inline-4 Turbo',
        type = 'i4',
        hp = 250,
        torque = 350,
        weight = 135.0,
        rpmMax = 7500,
        rpmRedline = 7000,
        fuelConsumption = 1.2,
        heatRate = 0.9,
        coolingEfficiency = 0.9,
        wearRate = 0.5,
        drivetrainCompat = { 'fwd', 'rwd', 'awd' },
        requiredParts = { 'motor_mount_i4', 'wiring_harness', 'ecu_adapter' },
        transmissionCompat = { '5speed', '6speed' },
        installTime = 200,
        price = 12000,
        torqueCurve = {
            { rpm = 1000, percent = 35 },
            { rpm = 2500, percent = 70 },
            { rpm = 3500, percent = 95 },
            { rpm = 5000, percent = 100 },
            { rpm = 6500, percent = 88 },
            { rpm = 7500, percent = 70 }
        }
    },
    ['v6_stock'] = {
        name = 'V6 3.5L Stock',
        type = 'v6',
        hp = 280,
        torque = 350,
        weight = 160.0,
        rpmMax = 6800,
        rpmRedline = 6200,
        fuelConsumption = 1.2,
        heatRate = 0.8,
        coolingEfficiency = 0.9,
        wearRate = 0.4,
        drivetrainCompat = { 'fwd', 'rwd', 'awd' },
        requiredParts = { 'motor_mount_v6', 'wiring_harness' },
        transmissionCompat = { '5speed', '6speed', '6speed_auto' },
        installTime = 220,
        price = 15000,
        torqueCurve = {
            { rpm = 1000, percent = 45 },
            { rpm = 2500, percent = 70 },
            { rpm = 4000, percent = 95 },
            { rpm = 5000, percent = 100 },
            { rpm = 6000, percent = 88 },
            { rpm = 6800, percent = 72 }
        }
    },
    ['v6_turbo'] = {
        name = 'V6 3.5L Twin-Turbo',
        type = 'v6',
        hp = 380,
        torque = 470,
        weight = 175.0,
        rpmMax = 7200,
        rpmRedline = 6600,
        fuelConsumption = 1.5,
        heatRate = 1.0,
        coolingEfficiency = 0.85,
        wearRate = 0.5,
        drivetrainCompat = { 'rwd', 'awd' },
        requiredParts = { 'motor_mount_v6', 'wiring_harness', 'ecu_adapter' },
        transmissionCompat = { '6speed', '6speed_auto' },
        installTime = 260,
        price = 22000,
        torqueCurve = {
            { rpm = 1000, percent = 45 },
            { rpm = 2500, percent = 75 },
            { rpm = 3500, percent = 95 },
            { rpm = 4500, percent = 100 },
            { rpm = 6000, percent = 90 },
            { rpm = 7200, percent = 72 }
        }
    },
    ['v8_stock'] = {
        name = 'V8 5.0L Stock',
        type = 'v8',
        hp = 360,
        torque = 500,
        weight = 180.0,
        rpmMax = 6500,
        rpmRedline = 6000,
        fuelConsumption = 1.6,
        heatRate = 1.0,
        coolingEfficiency = 0.85,
        wearRate = 0.4,
        drivetrainCompat = { 'rwd', 'awd' },
        requiredParts = { 'motor_mount_v8', 'wiring_harness' },
        transmissionCompat = { '5speed', '6speed', '6speed_auto' },
        installTime = 280,
        price = 20000,
        torqueCurve = {
            { rpm = 1000, percent = 50 },
            { rpm = 2000, percent = 70 },
            { rpm = 3500, percent = 90 },
            { rpm = 4500, percent = 100 },
            { rpm = 5500, percent = 92 },
            { rpm = 6500, percent = 78 }
        }
    },
    ['v8_ls3'] = {
        name = 'LS3 6.2L V8',
        type = 'v8',
        hp = 430,
        torque = 580,
        weight = 185.0,
        rpmMax = 6600,
        rpmRedline = 6000,
        fuelConsumption = 1.8,
        heatRate = 1.2,
        coolingEfficiency = 0.8,
        wearRate = 0.5,
        drivetrainCompat = { 'rwd', 'awd' },
        requiredParts = { 'motor_mount_v8', 'wiring_harness', 'ecu_adapter' },
        transmissionCompat = { '5speed', '6speed', '6speed_auto' },
        installTime = 300,
        price = 25000,
        torqueCurve = {
            { rpm = 1000, percent = 50 },
            { rpm = 2000, percent = 70 },
            { rpm = 3500, percent = 95 },
            { rpm = 4500, percent = 100 },
            { rpm = 5500, percent = 92 },
            { rpm = 6600, percent = 78 }
        }
    }
}

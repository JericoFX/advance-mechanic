Config = {}

-- Debug mode
Config.Debug = false

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

-- Shop creation settings
Config.ShopCreation = {
    basePrice = 100000,
    maxLifts = 4,
    requiresAdmin = true,
    requiredZones = {
        management = {label = 'Management Point', icon = 'fas fa-briefcase'},
        storage = {label = 'Storage Area', icon = 'fas fa-warehouse'},
        inspection = {label = 'Inspection Area', icon = 'fas fa-search'},
        garage = {label = 'Service Vehicle Garage', icon = 'fas fa-garage'},
        paint = {label = 'Paint Booth', icon = 'fas fa-spray-can'},
        parts = {label = 'Parts Shop', icon = 'fas fa-shopping-cart'},
        customer = {label = 'Customer Waiting Area', icon = 'fas fa-chair'}
    },
    vehicleSpawns = {
        service = {label = 'Service Vehicles', max = 3},
        customer = {label = 'Customer Parking', max = 5}
    }
}

-- Vehicle damage settings
Config.VehicleDamage = {
    enabled = true,
    damageMultiplier = 1.0,
    wheelMisalignmentThreshold = 0.3, -- 30% damage causes misalignment
    engineFailureThreshold = 0.1, -- 10% health causes engine failure
    degradePerKm = 0.001, -- 0.1% per km
}

-- Inspection settings
Config.Inspection = {
    checkPoints = {
        engine = {label = 'Engine', degradeRate = 0.002},
        brakes = {label = 'Brakes', degradeRate = 0.003},
        oil = {label = 'Oil', degradeRate = 0.004},
        battery = {label = 'Battery', degradeRate = 0.001},
        transmission = {label = 'Transmission', degradeRate = 0.002},
        coolant = {label = 'Coolant', degradeRate = 0.003},
        suspension = {label = 'Suspension', degradeRate = 0.002},
        tires = {label = 'Tires', degradeRate = 0.004}
    },
    requiredTool = 'diagnostic_tool'
}

-- Maintenance items
Config.MaintenanceItems = {
    oil = {item = 'engine_oil', label = 'Engine Oil', restores = 100},
    brakefluid = {item = 'brake_fluid', label = 'Brake Fluid', restores = 100},
    coolant = {item = 'coolant', label = 'Coolant', restores = 100},
    battery = {item = 'car_battery', label = 'Car Battery', restores = 100}
}

-- Vehicle parts
Config.VehicleParts = {
    door = {item = 'car_door', label = 'Car Door', price = 500},
    hood = {item = 'car_hood', label = 'Hood', price = 400},
    trunk = {item = 'car_trunk', label = 'Trunk', price = 450},
    wheel = {item = 'car_wheel', label = 'Wheel', price = 300},
    window = {item = 'car_window', label = 'Window', price = 200},
    bumper = {item = 'car_bumper', label = 'Bumper', price = 350}
}

-- Tools required
Config.Tools = {
    basic = {
        {item = 'toolbox', label = 'Toolbox'},
        {item = 'wrench', label = 'Wrench'}
    },
    advanced = {
        {item = 'diagnostic_tool', label = 'Diagnostic Tool'},
        {item = 'welding_torch', label = 'Welding Torch'},
        {item = 'hydraulic_jack', label = 'Hydraulic Jack'}
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
    cooldown = 300, -- 5 minutes between missions
    locations = {
        {coords = vec4(25.73, -1347.27, 29.5, 270.0), radius = 50.0},
        {coords = vec4(-354.37, -135.4, 39.01, 70.0), radius = 50.0},
        {coords = vec4(1163.34, -323.09, 69.21, 100.0), radius = 50.0}
    },
    vehicles = {
        'sultan', 'buffalo', 'dominator', 'gauntlet', 'phoenix'
    },
    payouts = {
        inspection = {min = 100, max = 200},
        repair = {min = 300, max = 600},
        towing = {min = 400, max = 800}
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

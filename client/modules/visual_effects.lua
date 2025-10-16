local VisualEffects = {}

-- Particle effect configurations
local particleEffects = {
    welding = {
        dict = "core",
        name = "ent_brk_sparking_wires",
        scale = 0.5,
        duration = 1000
    },
    smoke = {
        dict = "core",
        name = "ent_sht_steam",
        scale = 0.3,
        duration = 2000
    },
    sparks = {
        dict = "core", 
        name = "ent_dst_elec_fire_sp",
        scale = 0.4,
        duration = 500
    },
    oil_drip = {
        dict = "core",
        name = "ent_sht_oil",
        scale = 0.2,
        duration = 3000
    }
}

-- Enhanced animation configurations
local animations = {
    engine_repair = {
        dict = "mini@repair",
        clip = "fixing_a_ped",
        flag = 16,
        prop = {
            model = "prop_tool_wrench",
            bone = 57005,
            pos = vec3(0.13, 0.04, -0.02),
            rot = vec3(100.0, 0.0, 0.0)
        }
    },
    welding = {
        dict = "amb@world_human_welding@male@base",
        clip = "base",
        flag = 49,
        prop = {
            model = "prop_weld_torch",
            bone = 57005,
            pos = vec3(0.13, 0.04, -0.02),
            rot = vec3(100.0, 0.0, 0.0)
        }
    },
    tire_change = {
        dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        clip = "machinic_loop_mechandplayer",
        flag = 16,
        prop = {
            model = "prop_tool_fireaxe",
            bone = 57005,
            pos = vec3(0.13, 0.04, -0.02),
            rot = vec3(100.0, 0.0, 0.0)
        }
    },
    diagnostic = {
        dict = "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a",
        clip = "idle_a",
        flag = 49,
        prop = {
            model = "prop_cs_tablet",
            bone = 28422,
            pos = vec3(0.03, 0.002, -0.0),
            rot = vec3(10.0, 160.0, 0.0)
        }
    }
}

function VisualEffects.PlayAnimation(animationType, duration)
    local animData = animations[animationType]
    if not animData then return end
    
    local ped = PlayerPedId()
    
    -- Load animation
    lib.requestAnimDict(animData.dict)
    
    -- Create prop if needed
    local prop = nil
    if animData.prop then
        lib.requestModel(animData.prop.model)
        prop = CreateObject(animData.prop.model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, animData.prop.bone),
            animData.prop.pos.x, animData.prop.pos.y, animData.prop.pos.z,
            animData.prop.rot.x, animData.prop.rot.y, animData.prop.rot.z,
            true, true, false, true, 1, true)
    end
    
    -- Play animation
    TaskPlayAnim(ped, animData.dict, animData.clip, 8.0, -8.0, duration or -1, animData.flag, 0, false, false, false)
    
    return prop
end

function VisualEffects.StopAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
end

function VisualEffects.CreateParticleAtCoords(effectType, coords, duration)
    local effect = particleEffects[effectType]
    if not effect then return end
    
    -- Request particle dictionary
    lib.requestNamedPtfxAsset(effect.dict)
    
    -- Use particle effect
    UseParticleFxAssetNextCall(effect.dict)
    local particleHandle = StartParticleFxLoopedAtCoord(
        effect.name,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        effect.scale,
        false, false, false
    )
    
    -- Stop particle after duration
    if duration then
        SetTimeout(duration or effect.duration, function()
            StopParticleFxLooped(particleHandle, false)
        end)
    end
    
    return particleHandle
end

function VisualEffects.CreateParticleOnEntity(effectType, entity, offset, duration)
    local effect = particleEffects[effectType]
    if not effect then return end
    
    -- Request particle dictionary
    lib.requestNamedPtfxAsset(effect.dict)
    
    -- Use particle effect
    UseParticleFxAssetNextCall(effect.dict)
    local particleHandle = StartParticleFxLoopedOnEntity(
        effect.name,
        entity,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        effect.scale,
        false, false, false
    )
    
    -- Stop particle after duration
    if duration then
        SetTimeout(duration or effect.duration, function()
            StopParticleFxLooped(particleHandle, false)
        end)
    end
    
    return particleHandle
end

function VisualEffects.WeldingEffect(vehicle, duration)
    local coords = GetEntityCoords(vehicle)
    local offset = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.0, 0.0)
    
    -- Play welding animation
    local prop = VisualEffects.PlayAnimation('welding', duration)
    
    -- Create sparks effect
    local sparkHandle = VisualEffects.CreateParticleAtCoords('sparks', offset, duration)
    
    -- Create smoke effect
    local smokeHandle = VisualEffects.CreateParticleAtCoords('smoke', offset, duration)
    
    -- Clean up after duration
    SetTimeout(duration, function()
        if prop then
            DeleteObject(prop)
        end
        VisualEffects.StopAnimation()
    end)
    
    return {prop = prop, sparks = sparkHandle, smoke = smokeHandle}
end

function VisualEffects.EngineRepairEffect(vehicle, duration)
    -- Play engine repair animation
    local prop = VisualEffects.PlayAnimation('engine_repair', duration)

    local active = true
    local sparkTicker
    local sparkLoopTimeout
    local activeSparkHandles = {}

    local function getEngineCoords()
        local boneIndex = GetEntityBoneIndexByName(vehicle, "engine")
        if boneIndex ~= -1 then
            local coords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            if coords then
                return coords
            end
        end

        local vehicleCoords = GetEntityCoords(vehicle)
        return vec3(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5)
    end

    local function spawnSpark()
        if not active then return end

        local coords = getEngineCoords()
        if not coords then return end

        local handle = VisualEffects.CreateParticleAtCoords('sparks', coords, particleEffects.sparks.duration)
        if handle then
            activeSparkHandles[#activeSparkHandles + 1] = handle

            SetTimeout(particleEffects.sparks.duration or 500, function()
                for index = #activeSparkHandles, 1, -1 do
                    if activeSparkHandles[index] == handle then
                        table.remove(activeSparkHandles, index)
                        break
                    end
                end
            end)
        end
    end

    local function stopSparkLoop()
        if sparkTicker and sparkTicker.forceEnd then
            sparkTicker:forceEnd()
        end

        if sparkLoopTimeout then
            ClearTimeout(sparkLoopTimeout)
        end

        sparkTicker = nil
        sparkLoopTimeout = nil
    end

    local function cleanup()
        if not active then return end
        active = false

        stopSparkLoop()

        for index = #activeSparkHandles, 1, -1 do
            local handle = activeSparkHandles[index]
            if handle then
                StopParticleFxLooped(handle, false)
            end
            activeSparkHandles[index] = nil
        end

        if prop then
            DeleteObject(prop)
            prop = nil
        end

        VisualEffects.StopAnimation()
    end

    spawnSpark()

    if lib and lib.timer then
        sparkTicker = lib.timer(2000, function()
            if not active then
                stopSparkLoop()
                return
            end

            spawnSpark()
        end)
    else
        local function scheduleNextSpark()
            if not active then return end

            spawnSpark()
            sparkLoopTimeout = SetTimeout(2000, scheduleNextSpark)
        end

        sparkLoopTimeout = SetTimeout(2000, scheduleNextSpark)
    end

    if duration and duration > 0 then
        SetTimeout(duration, cleanup)
    end

    return {
        prop = prop,
        stop = cleanup
    }
end

function VisualEffects.OilLeakEffect(vehicle)
    local offset = vec3(0.0, -1.5, -0.5)
    return VisualEffects.CreateParticleOnEntity('oil_drip', vehicle, offset, 5000)
end

function VisualEffects.CheckHoodOpen(vehicle)
    return IsVehicleDoorFullyOpen(vehicle, 4) -- 4 is the hood door index
end

function VisualEffects.OpenHood(vehicle)
    SetVehicleDoorOpen(vehicle, 4, false, false)
end

function VisualEffects.CloseHood(vehicle)
    SetVehicleDoorShut(vehicle, 4, false)
end

function VisualEffects.CreateWorkLight(coords)
    -- Create a bright light for working under the hood
    local handle = CreateObject(`prop_construcionlamp_01`, coords.x, coords.y, coords.z + 2.0, true, true, false)
    SetEntityHeading(handle, 0.0)
    FreezeEntityPosition(handle, true)
    
    -- Create light effect
    DrawLightWithRange(coords.x, coords.y, coords.z + 1.0, 255, 255, 255, 5.0, 10.0)
    
    return handle
end

return VisualEffects

# Recomendaciones para Advanced Mechanic System

## Correcciones Críticas Necesarias

### 1. Eliminar Exports del Mismo Recurso
**Problema**: Se detectó uso de exports dentro del mismo recurso en `client/modules/shops.lua`
**Ubicación**: Línea 67-84
```lua
-- ACTUAL (INCORRECTO)
exports.ox_target:addSphereZone({
    coords = shop.zones.inspection,
    radius = 5.0,
    options = {
        {
            name = 'inspect_vehicle',
            icon = 'fas fa-search',
            label = locale('inspect_vehicle'),
            canInteract = function(entity, distance, coords, name)
                return cache.vehicle ~= nil
            end,
            onSelect = function()
                local Inspection = require 'client.modules.inspection'
                Inspection.Inspect(cache.vehicle)
            end
        }
    }
})
```

**Solución**: Usar ox_lib.points en su lugar
```lua
-- CORRECTO
local inspectionZone = lib.points.new({
    coords = shop.zones.inspection,
    distance = 5,
    shop = shop
})

function inspectionZone:nearby()
    if self.currentDistance < 3.0 and cache.vehicle then
        lib.showTextUI(locale('inspect_vehicle'))
        
        if IsControlJustPressed(0, 38) then
            local Inspection = require 'client.modules.inspection'
            Inspection.Inspect(cache.vehicle)
        end
    end
end

function inspectionZone:onExit()
    lib.hideTextUI()
end
```

### 2. Corregir Sintaxis de ox_lib.setVehicleProperties
**Problema**: Se usa sintaxis incorrecta para setVehicleProperties
**Ubicación**: Archivo `server/modules/shops.lua` línea 175-190

**Solución**: Usar ox module correctamente
```lua
-- CORRECTO
local ox = require '@ox_core/lib/init'
ox.setVehicleProperties(vehicle, {
    plate = plate,
    bodyHealth = 1000.0,
    engineHealth = 1000.0,
    fuelLevel = 100.0
})
```

### 3. Problema en Menu de Creación - Coordenadas
**Problema**: El menú de creación no funciona correctamente para obtener coordenadas
**Ubicación**: `client/modules/shops.lua` línea 163-257

**Solución**: Implementar freecam para ubicación de puntos
```lua
function Shops.StartCreation()
    creationMode = true
    creationData = {
        zones = {},
        lifts = {},
        vehicleSpawns = {
            service = {},
            customer = {}
        }
    }
    
    lib.notify({
        title = locale('shop_creation_started'),
        description = locale('follow_instructions'),
        type = 'info'
    })
    
    -- Habilitar freecam
    local freecam = lib.requestAnimDict('anim@heists@prison_heistlg_1_p1_guard')
    
    -- Crear zonas requeridas con freecam
    for zoneName, zoneConfig in pairs(Config.ShopCreation.requiredZones) do
        local coords = Shops.GetPositionWithFreecam(zoneConfig.label)
        if coords then
            creationData.zones[zoneName] = coords
            lib.notify({
                title = string.format(locale('zone_placed'), zoneConfig.label),
                type = 'success'
            })
        end
    end
    
    -- Resto del código...
end

function Shops.GetPositionWithFreecam(label)
    lib.showTextUI(string.format(locale('place_zone'), label))
    
    -- Habilitar freecam
    SetFreecamActive(true)
    
    local coords = nil
    local finished = false
    
    CreateThread(function()
        while not finished do
            Wait(0)
            
            if IsControlJustPressed(0, 38) then -- E
                coords = GetEntityCoords(PlayerPedId())
                finished = true
            end
            
            if IsControlJustPressed(0, 194) then -- BACKSPACE
                finished = true
            end
        end
    end)
    
    -- Esperar hasta que se termine
    while not finished do
        Wait(100)
    end
    
    SetFreecamActive(false)
    lib.hideTextUI()
    
    return coords
end
```

### 4. Verificar Comandos de Administrador
**Problema**: Usar lib.addCommand en lugar de QBCore commands
**Ubicación**: Crear comando para iniciar creación de talleres

**Solución**: Implementar comando con ox_lib
```lua
-- Agregar al client/init.lua
lib.addCommand('createshop', {
    help = locale('create_shop_help'),
    restricted = 'group.admin'
}, function(source, args, raw)
    local Shops = require 'client.modules.shops'
    Shops.StartCreation()
end)
```

### 5. Usar ox_lib para Strings Localizados
**Problema**: Strings hardcodeados en el código
**Ubicación**: Varios archivos

**Solución**: Actualizar `locales/en.json`
```json
{
    "press_to_manage_shop": "Press [E] to manage shop",
    "shop_info": "Shop Information",
    "owner_format": "Owner: %s",
    "no_owner": "No Owner",
    "spawn_service_vehicle": "Spawn Service Vehicle",
    "manage_employees": "Manage Employees",
    "service_vehicles": "Service Vehicles",
    "vehicle_spawned": "Vehicle Spawned",
    "shop_creation_started": "Shop Creation Started",
    "follow_instructions": "Follow the instructions to create your shop",
    "place_zone": "Place %s zone - Press [E] to confirm",
    "zone_placed": "%s zone placed successfully",
    "place_lift_entry": "Place lift entry point - Press [E] to confirm",
    "place_lift_position": "Place lift position - Press [E] to confirm",
    "place_lift_control": "Place lift control panel - Press [E] to confirm",
    "add_another_lift": "Add Another Lift?",
    "lifts_added_format": "Lifts added: %d/%d",
    "place_spawn_point": "Place %s spawn point %d - Press [E] to confirm",
    "shop_details": "Shop Details",
    "shop_name": "Shop Name",
    "shop_price": "Shop Price",
    "no_permission": "No Permission",
    "shop_created": "Shop Created",
    "shop_created_desc": "Shop '%s' has been created successfully",
    "shop_already_owned": "Shop Already Owned",
    "insufficient_funds": "Insufficient Funds",
    "shop_purchased": "Shop Purchased",
    "shop_purchased_desc": "You purchased '%s' successfully",
    "not_shop_owner": "Not Shop Owner",
    "shop_sold": "Shop Sold",
    "shop_sold_desc": "Shop sold for $%d",
    "not_mechanic": "Not a Mechanic",
    "inspect_vehicle": "Inspect Vehicle",
    "create_shop_help": "Create a new mechanic shop"
}
```

### 6. Implementar Cache de Vehículos
**Problema**: No se usa lib.onCache para verificar vehículo y asiento
**Ubicación**: `client/modules/shops.lua`

**Solución**: Usar ox_lib cache
```lua
-- Agregar al inicio del archivo
lib.onCache('vehicle', function(vehicle)
    if vehicle then
        -- Jugador entró a un vehículo
        -- Actualizar UI o lógica necesaria
    else
        -- Jugador salió del vehículo
        -- Limpiar UI o estados
    end
end)

lib.onCache('seat', function(seat)
    -- Verificar si está en el asiento del conductor
    if seat == -1 then
        -- Es el conductor
    end
end)
```

### 7. Problema con Verificación de Todas las Zonas
**Análisis del Menu de Creación**:
El menú actual **NO** permite ubicar todos los puntos correctamente porque:

1. **Obtención de Coordenadas**: `lib.getCoords()` no es interactivo
2. **Falta Freecam**: No hay sistema de freecam implementado
3. **Flujo Automático**: No permite al usuario posicionarse correctamente

**Solución**: Implementar sistema de freecam con confirmación manual para cada punto.

## Checklist de Implementación

- [x] Eliminar exports del mismo recurso en shops.lua
- [x] Corregir sintaxis ox_lib.setVehicleProperties
- [x] Implementar freecam para creación de talleres
- [x] Agregar comando admin con lib.addCommand
- [x] Actualizar todos los strings a locales
- [x] Implementar lib.onCache para vehículos
- [x] Verificar funcionamiento del menú de creación
- [x] Probar creación completa de taller
- [x] Verificar que todos los puntos se pueden ubicar
- [x] Documentar proceso de creación

## Notas Importantes

1. **Freecam es crucial** para la correcta ubicación de puntos
2. **Verificar cada zona** antes de finalizar la creación
3. **Usar callback del servidor** para verificar permisos de admin
4. **Implementar validación** de distancias entre puntos
5. **Guardar coordenadas** con precisión decimal completa

## Archivos que Necesitan Modificación

- `client/modules/shops.lua` - Correcciones principales
- `server/modules/shops.lua` - Sintaxis ox_lib
- `locales/en.json` - Strings localizados
- `client/init.lua` - Comandos de admin
- `shared/config.lua` - Configuraciones adicionales si es necesario

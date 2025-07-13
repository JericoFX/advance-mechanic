# Fluid Effects Module - Flow Analysis

## Checklist de Verificación ✓

### 1. Inicialización del Sistema
- [ ] **Client Init (client/init.lua)**
  - Línea 17: `FluidEffects = require 'client.modules.fluid_effects'` - Carga del módulo
  - Línea 33: `FluidEffects.Monitor()` - Inicia monitoreo al cargar jugador
  - Línea 49: `FluidEffects.Monitor()` - Inicia monitoreo si recurso reinicia

### 2. Sistema de Monitoreo (client/modules/fluid_effects.lua)
- [ ] **Monitor Function (línea 182-199)**
  - `lib.onCache('vehicle')` - Detecta entrada/salida de vehículo
  - `lib.onCache('seat')` - Detecta cambio de asiento
  - Solo activa efectos si jugador es conductor (seat == -1)

### 3. Thread Principal de Efectos (líneas 9-30)
- [ ] **Condiciones de Ejecución**
  - Verifica cada 1000ms (1 segundo)
  - Solo ejecuta si: `vehicle` existe Y `cache.seat == -1`
  - Obtiene niveles de fluidos del estado del vehículo

### 4. Obtención de Datos de Fluidos
- [ ] **Server Side (server/modules/vehicles.lua)**
  - Línea 25-42: `GetFluidData()` - Obtiene datos de DB o valores default
  - Línea 246-248: Callback registrado para obtener datos
  - Línea 250-252: Callback para actualizar datos

### 5. Aplicación de Efectos

#### A. Efectos de Frenos (líneas 39-82)
- [ ] **Niveles Críticos (<30%)**
  - Reduce fuerza de frenado a 30% del original
  - Muestra notificación de error (líneas 54-59)
  - Guarda estado de advertencia para evitar spam
  
- [ ] **Niveles Bajos (<50%)**
  - Reduce fuerza de frenado a 60% del original
  - Muestra notificación de advertencia (líneas 68-73)
  
- [ ] **Niveles Normales (≥50%)**
  - Restaura fuerza de frenado original
  - Limpia estado de advertencia

#### B. Efectos de Motor (líneas 84-146)
- [ ] **Aceite Bajo (<30%)**
  - Daña motor continuamente (-0.5 salud/segundo)
  - Reduce velocidad máxima a 70%
  - Notificación de error (líneas 98-103)
  
- [ ] **Refrigerante Bajo (<30%)**
  - Aumenta temperatura +2°C/segundo
  - Si temperatura > 120°C: Apaga motor automáticamente
  - Activa humo del motor (línea 128)
  - Notificaciones según severidad

#### C. Efectos de Dirección (líneas 148-180)
- [ ] **Fluido Crítico (<30%)**
  - Reduce ángulo de giro a 25° (muy pesado)
  - Notificación de advertencia
  
- [ ] **Fluido Bajo (<50%)**
  - Reduce ángulo de giro a 35° (ligeramente pesado)
  - Notificación informativa

### 6. Posibles Errores y Soluciones

#### Error 1: Datos de Fluidos No Sincronizados
```lua
-- Problema: vehicleState.brakeFluidLevel puede ser nil
-- Solución actual: Línea 17-20 usa "or 100" como fallback
local brakeFluid = vehicleState.brakeFluidLevel or 100
```

#### Error 2: Memory Leak con originalHandling
```lua
-- Problema: originalHandling nunca se limpia para vehículos anteriores
-- Solución necesaria: Limpiar tabla cuando jugador sale del vehículo
function FluidEffects.Stop()
    if effectsThread then
        effectsThread = nil
    end
    -- Agregar limpieza de memoria
    for vehicle, _ in pairs(originalHandling) do
        if not DoesEntityExist(vehicle) then
            originalHandling[vehicle] = nil
        end
    end
end
```

#### Error 3: Múltiples Notificaciones
```lua
-- Problema: Las notificaciones pueden aparecer cada segundo
-- Solución actual: Se usa Entity.state para trackear advertencias mostradas
-- Líneas 52, 67, 97, 130, 154, 167
```

#### Error 4: Sincronización Cliente-Servidor
```lua
-- Problema: Los datos de fluidos pueden no estar actualizados
-- Necesario: Implementar sincronización periódica
-- Actualmente depende de callbacks manuales
```

### 7. Flujo Completo desde Perspectiva del Jugador

1. **Jugador entra al servidor**
   - QBCore:Client:OnPlayerLoaded dispara
   - FluidEffects.Monitor() inicia
   
2. **Jugador entra a un vehículo como conductor**
   - lib.onCache('vehicle') detecta cambio
   - lib.onCache('seat') verifica que es conductor
   - FluidEffects.Start() inicia thread
   
3. **Cada segundo mientras conduce**
   - Thread verifica niveles de fluidos
   - Aplica efectos según niveles:
     - Frenos: Modifica fBrakeForce
     - Motor: Modifica salud y velocidad
     - Dirección: Modifica fSteeringLock
   
4. **Jugador recibe feedback**
   - Notificaciones visuales con ox_lib
   - Cambios físicos en manejo del vehículo
   - Efectos visuales (humo si motor sobrecalentado)
   
5. **Jugador sale del vehículo**
   - lib.onCache detecta cambio
   - FluidEffects.Stop() detiene thread
   - originalHandling debería limpiarse (bug potencial)

### 8. Integración con Sistema de Mantenimiento

- [ ] Los mecánicos pueden rellenar fluidos usando items de Config.MaintenanceItems
- [ ] Los datos se guardan en DB mediante Vehicles.UpdateFluidData()
- [ ] La UI de diagnóstico muestra niveles actuales (diagnostic.lua)
- [ ] Los fluidos se degradan con el tiempo (no implementado aún)

### 9. Validaciones de Seguridad

- [ ] ✓ Verifica que jugador sea conductor
- [ ] ✓ Verifica que vehículo exista
- [ ] ✓ Usa valores default si datos no existen
- [ ] ✗ No valida permisos para modificar handling (potencial exploit)
- [ ] ✗ No limpia memoria de vehículos antiguos

### 10. Mejoras Recomendadas

1. **Agregar degradación automática de fluidos**
```lua
-- En el thread principal
if GetVehicleEngineHealth(vehicle) < 1000 then
    -- Reducir aceite más rápido si motor dañado
    local currentOil = vehicleState.oilLevel or 100
    Entity(vehicle).state:set('oilLevel', math.max(0, currentOil - 0.1), true)
end
```

2. **Sincronización periódica con servidor**
```lua
-- Cada 5 minutos, sincronizar con DB
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutos
        if cache.vehicle then
            local plate = GetVehicleNumberPlateText(cache.vehicle)
            lib.callback('mechanic:server:syncFluidData', false, function(data)
                -- Actualizar estado local
            end, plate)
        end
    end
end)
```

3. **Limpieza de memoria**
```lua
-- Agregar en FluidEffects.Stop()
originalHandling = {}
```

## Conclusión

El sistema funciona correctamente en su flujo principal pero tiene algunas áreas de mejora:
- Memory leaks potenciales con originalHandling
- Falta degradación automática de fluidos
- Necesita mejor sincronización cliente-servidor
- Podría beneficiarse de validaciones adicionales de seguridad

El jugador experimenta los efectos correctamente según los niveles de fluidos, con feedback visual y físico apropiado.

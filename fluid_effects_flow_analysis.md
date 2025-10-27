# Fluid Effects Module - Flow Analysis

## Checklist de Verificación ✓

### 1. Inicialización del Sistema
- [x] **Client Init (`client/init.lua`)**
  - `local FluidEffects = require 'client.modules.fluid_effects'` - Carga el orquestador.
  - `FluidEffects.Monitor()` - Activa el monitoreo cuando el jugador se conecta o al reiniciar el recurso.

### 2. Arquitectura Modular (client/modules/fluid)
- [x] **`fluid/effects.lua`**
  - Agrupa la lógica de aplicación de efectos (frenos, motor, dirección, neumáticos, batería, caja de cambios).
  - Usa `Entity(vehicle).state` para debouncing de notificaciones con ox_lib.
- [x] **`fluid/degradation.lua`**
  - Encapsula desgaste periódico, degradación de fluidos y respuesta a colisiones.
- [x] **`fluid/state.lua`**
  - Sincroniza datos con el servidor mediante `lib.callback.await` y `TriggerServerEvent`.

### 3. Sistema de Monitoreo (`client/modules/fluid_effects.lua`)
- [x] `lib.onCache('vehicle')` y `lib.onCache('seat')` detectan cambios de vehículo y asiento.
- [x] `startCleanupThread()` realiza limpieza cada 10 minutos utilizando el estado compartido.
- [x] `startCollisionWatcher()` aisla la detección de impactos para aplicar desgaste adicional solo cuando hay un vehículo monitoreado.

### 4. Thread Principal de Efectos
- [x] Se crea con `CreateThread` únicamente cuando el jugador es conductor.
- [x] Intervalo base de 1000 ms; se extiende a 1500 ms cuando el jugador no cumple condiciones para reducir uso de CPU.
- [x] Usa datos en caché (`Entity(vehicle).state`) para evitar accesos redundantes.
- [x] Sincroniza con el servidor cada 5 minutos y degrada fluidos/componentes cada 30 segundos o al recorrer 1 unidad de millaje virtual.

### 5. Obtención de Datos de Fluidos
- [x] `State.fetchInitialData()` llama a `mechanic:server:getVehicleFluidData` utilizando `ox_lib`.
- [x] `State.applyInitialData()` prepara el estado local antes de iniciar efectos.
- [x] `State.pushToServer()` envía actualizaciones con `mechanic:server:syncFluidLevels`.

### 6. Aplicación de Efectos (Resumen)
- **Frenos:** Ajusta `fBrakeForce` según nivel y muestra notificaciones escalonadas.
- **Motor:** Gestiona daños por aceite bajo, sobrecalentamiento y restablece temperatura progresivamente.
- **Dirección:** Cambia `fSteeringLock` para simular dirección pesada.
- **Neumáticos:** Controla probabilidad de reventón y tracción (`fTractionCurveMax/Min`).
- **Batería:** Atenúa luces y apaga motor cuando el nivel es crítico.
- **Caja de Cambios:** Simula cambios aleatorios o lentitud según salud de transmisión.

### 7. Estrategias de Rendimiento
- Uso de caché de handling (`handlingCache`) para restaurar valores originales al salir del vehículo.
- Limpieza periódica mediante `State.cleanupHandlingCache()` para evitar fugas de memoria.
- Separación de responsabilidades en módulos dedicados para facilitar pruebas unitarias y mantenibilidad.

### 8. Flujo Completo desde Perspectiva del Jugador
1. **Jugador entra al servidor:** `FluidEffects.Monitor()` queda escuchando cambios de cache.
2. **Jugador se sube como conductor:** `FluidEffects.Start(vehicle)` inicializa datos y lanza el thread principal.
3. **Conducción:** Cada ciclo aplica efectos, degrada componentes y sincroniza con el servidor según corresponda.
4. **Jugador deja de conducir:** `FluidEffects.Stop()` detiene el thread, restaura handling y sincroniza los niveles finales.

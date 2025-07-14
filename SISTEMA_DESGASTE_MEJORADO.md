# Sistema de Desgaste Mejorado - Advanced Mechanic System

## Resumen de Implementación

Se ha implementado un sistema completo de desgaste de vehículos que va más allá de los fluidos básicos, incluyendo componentes mecánicos y eléctricos que se deterioran de manera realista.

## Nuevos Componentes de Desgaste

### 1. Desgaste de Neumáticos
- **Factor de Velocidad**: Velocidad > 80 km/h duplica el desgaste, > 150 km/h lo triplica
- **Superficie del Terreno**: Arena y rocas aumentan el desgaste 50%
- **Efectos del Desgaste**:
  - 60-80%: Reducción de tracción, advertencia amarilla
  - >80%: Riesgo de explosión (0.5% probabilidad), tracción crítica
- **Consecuencias**: Explosión de neumáticos, pérdida de control del vehículo

### 2. Sistema de Batería
- **Factores de Desgaste**:
  - Motor dañado (<800 HP): Doble consumo
  - Ralentí prolongado: 50% más consumo
- **Efectos del Desgaste**:
  - 20-40%: Luces débiles, advertencia
  - <20%: Apagones aleatorios del motor (10% probabilidad)
- **Consecuencias**: Vehículo no arranca, luces muy débiles

### 3. Caja de Cambios/Transmisión
- **Factores de Desgaste**:
  - Velocidad > 120 km/h: Doble desgaste
  - Carrocería dañada: 50% más desgaste
- **Efectos del Desgaste**:
  - 30-60%: Cambios lentos, fallos ocasionales
  - <30%: Cambios aleatorios de marcha (5% probabilidad)
- **Consecuencias**: Pérdida de control de marchas, conducción impredecible

## Detección de Colisiones

### Sistema de Monitoreo
- **Frecuencia**: Verificación cada 0.5 segundos
- **Umbral de Daño**: Colisiones > 20 puntos de daño
- **Distribución del Daño**:
  - Batería: 10% del daño de colisión
  - Caja de Cambios: 15% del daño de colisión
  - Neumáticos: 20% del daño (solo colisiones > 50 puntos)

## Kilometraje y Desgaste Basado en Uso

### Sistema de Kilometraje
- **Tracking**: Monitoreo continuo de distancia recorrida
- **Degradación Progresiva**: Componentes se desgastan según uso real
- **Factores Múltiples**:
  - Velocidad promedio
  - Tiempo de uso
  - Condiciones de manejo
  - Estado general del vehículo

## Características Técnicas

### Optimización de Rendimiento
- **Cache System**: Uso de ox_lib cache para eficiencia
- **Memory Management**: Limpieza automática cada 10 minutos
- **Sync Inteligente**: Sincronización cada 5 minutos con base de datos
- **Validación Server-Side**: Prevención de cheating

### Base de Datos Mejorada
- **Tablas Nuevas**:
  - `vehicle_maintenance_history`: Historial completo de mantenimiento
  - `vehicle_component_analytics`: Análisis detallado de componentes
- **Campos Expandidos**:
  - `component_data`: Datos detallados de componentes
  - `mileage`: Kilometraje total
  - `last_service`: Último servicio realizado

## Interfaz de Usuario

### Notificaciones Mejoradas
- **Sistema de Advertencias**: Múltiples niveles de severidad
- **Prevención de Spam**: Una notificación por tipo de problema
- **Colores Contextuales**: Error (rojo), Warning (amarillo), Info (azul)

### Localización Completa
- **18 Nuevos Strings**: Todos los mensajes localizados
- **Soporte Multiidioma**: Fácil expansión a otros idiomas
- **Consistencia**: Formato uniforme en todas las notificaciones

## Mecánicas de Reparación

### Sistema de Reparación por Componentes
- **Callback Server**: `mechanic:server:repairComponent`
- **Componentes Reparables**:
  - Neumáticos → tireWear = 0
  - Batería → batteryLevel = 100
  - Caja de Cambios → gearBoxHealth = 100
  - Fluidos → Niveles específicos = 100
- **Costo Variable**: Cada componente tiene su precio de reparación

## Configuración Avanzada

### Tasas de Desgaste Personalizables
```lua
-- Configuración base de desgaste por componente
TireWearRate = 0.01  -- Por ciclo de degradación
BatteryDrainRate = 0.02  -- Por ciclo de degradación
GearBoxDamageRate = 0.01  -- Por ciclo de degradación
```

### Multiplicadores de Condiciones
```lua
-- Multiplicadores según condiciones
HighSpeedMultiplier = 2.0  -- Velocidad > 80 km/h
ExtremeSpeedMultiplier = 3.0  -- Velocidad > 150 km/h
RoughTerrainMultiplier = 1.5  -- Arena/Rocas
DamagedEngineMultiplier = 2.0  -- Motor < 800 HP
```

## Beneficios del Sistema

### Para Jugadores
- **Realismo Mejorado**: Experiencia de manejo más auténtica
- **Consecuencias Realistas**: Decisiones de manejo importan
- **Progresión Natural**: Desgaste gradual y predecible

### Para Mecánicos
- **Trabajo Constante**: Demanda continua de servicios
- **Especialización**: Diferentes tipos de reparaciones
- **Economía Dinámica**: Precios variables según componente

### Para el Servidor
- **Inmersión**: Mayor realismo en el roleplay
- **Economía**: Circulación constante de dinero
- **Longevidad**: Contenido que se mantiene relevante

## Instalación y Migración

### Archivos Modificados
1. `client/modules/fluid_effects.lua` - Sistema principal expandido
2. `server/init.lua` - Callbacks y eventos del servidor
3. `locales/en.json` - Nuevos strings localizados
4. `enhanced_component_migration.sql` - Migración de base de datos

### Proceso de Instalación
1. Ejecutar migración SQL
2. Reiniciar recurso
3. Verificar logs de consola
4. Probar funcionalidades nuevas

## Monitoreo y Debugging

### Logs del Sistema
- Limpieza de memoria reportada en consola
- Errores de sincronización registrados
- Estadísticas de rendimiento disponibles

### Comandos de Testing
- Verificación de componentes en tiempo real
- Simulación de daños para pruebas
- Reset de componentes para debugging

Este sistema convierte el Advanced Mechanic System en una solución completa de simulación vehicular, proporcionando una experiencia realista y envolvente tanto para conductores como para mecánicos en el servidor FiveM.

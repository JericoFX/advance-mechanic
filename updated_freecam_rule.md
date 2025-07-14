# Regla Actualizada del Freecam

## Descripción
Siempre usar raycastFromCam de ox_lib para crear puntos en el sistema de mecánico, habilitando la funcionalidad después de configurar el menú de carrera.

## Implementación

### Función Principal
```lua
function GetPositionWithFreecam(label)
    lib.showTextUI(string.format(locale('place_zone'), label))
    
    local coords = nil
    local finished = false
    
    CreateThread(function()
        while not finished do
            Wait(0)
            
            -- Get raycast from camera
            local raycast = lib.raycast.fromCamera(511, 4, 10.0)
            
            if raycast.hit then
                -- Draw marker at hit position
                DrawMarker(
                    1, -- type
                    raycast.endCoords.x, raycast.endCoords.y, raycast.endCoords.z - 1.0, -- position
                    0.0, 0.0, 0.0, -- direction
                    0.0, 0.0, 0.0, -- rotation
                    2.0, 2.0, 1.0, -- scale
                    255, 255, 0, 100, -- color (yellow with alpha)
                    false, true, 2, false, false, false, false -- flags
                )
                
                -- Draw 3D text at hit position
                local onScreen, screenX, screenY = World3dToScreen2d(raycast.endCoords.x, raycast.endCoords.y, raycast.endCoords.z + 1.0)
                if onScreen then
                    SetTextScale(0.35, 0.35)
                    SetTextFont(0)
                    SetTextColour(255, 255, 255, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 150)
                    SetTextEntry("STRING")
                    AddTextComponentString(label)
                    DrawText(screenX, screenY)
                end
            end
            
            if IsControlJustPressed(0, 38) and raycast.hit then -- E
                coords = raycast.endCoords
                finished = true
            end
            
            if IsControlJustPressed(0, 194) then -- BACKSPACE
                finished = true
            end
        end
    end)
    
    while not finished do
        Wait(100)
    end
    
    lib.hideTextUI()
    
    return coords
end
```

### Características Principales

1. **Raycast desde Cámara**: Usa `lib.raycast.fromCamera(511, 4, 10.0)` para detectar donde está apuntando el jugador
2. **Visualizador en Tiempo Real**: Muestra un marcador amarillo en `raycast.endCoords` para indicar exactamente donde se colocará el punto
3. **Texto 3D**: Muestra el label del punto que se está colocando usando `World3dToScreen2d`
4. **Controles Intuitivos**: 
   - [E] para confirmar la colocación
   - [BACKSPACE] para cancelar
5. **Validación**: Solo permite colocar puntos cuando el raycast detecta una superficie válida

### Parámetros de Raycast
- `flags: 511` - Configuración estándar para detección de colisiones
- `ignore: 4` - Ignora tipos de colisionadores específicos
- `distance: 10.0` - Distancia máxima del raycast (10 metros)

### Ventajas
- **Precisión**: El raycast permite colocación exacta donde apunta la cámara
- **Feedback Visual**: El marcador amarillo muestra exactamente donde se colocará el punto
- **Interactividad**: Sistema responsivo que actualiza en tiempo real
- **Facilidad de Uso**: Controles simples y claros para el usuario
- **Cancelación**: Permite cancelar la operación en cualquier momento

Esta implementación reemplaza completamente el sistema anterior de freecam tradicional por uno más moderno y preciso usando las herramientas de ox_lib.

# Práctica 1 — Comunicación IoT: ESP32, sensor infrarrojo y móvil

**Objetivo:** detectar un objeto con un sensor IR, procesarlo en el ESP32 y
ver el estado en el teléfono por Bluetooth.

## Arquitectura IoT

| Capa | Componente en esta práctica |
|---|---|
| Percepción | Sensor infrarrojo en GPIO 27 (LOW = objeto) |
| Procesamiento | ESP32: decide si hay objeto y enciende el LED (GPIO 2) |
| Red | Bluetooth **clásico**, perfil SPP (puerto serie), nombre `ESP32_SENSOR_IR` |
| Aplicación | App BabyWolf → Prácticas → *Sensor IR · ESP32* |

## Implementación

- **Firmware:** `firmware/practica1_sensor_ir/` (script del docente sin cambios).
- **Puente Bluetooth:** `phone_app/android/.../SppBridge.kt`. `BluetoothSerial`
  es Bluetooth clásico (SPP), no BLE. Flutter no lo soporta de fábrica y los
  plugins de SPP están abandonados, así que la app abre directo un socket
  RFCOMM con el UUID estándar de SPP (`00001101-0000-1000-8000-00805F9B34FB`)
  y pasa cada línea a Flutter por un `EventChannel`.
- **Pantalla:** `lib/laboratorio/p1_iot/iot_screen.dart`. Muestra un indicador
  grande (OBJETO DETECTADO / SIN OBJETO), el estado del LED, la arquitectura y
  el historial con hora.
- **Interpretación:** `lectura_iot.dart`, cubierta por `test/lectura_iot_test.dart`.
- **Permisos:** `BLUETOOTH_CONNECT` en tiempo de ejecución desde Android 12.
  La app sólo usa dispositivos ya emparejados y no pide ubicación.

## Cómo probar

1. Cargar el firmware y emparejar `ESP32_SENSOR_IR` en los ajustes del teléfono.
2. App → 🧪 → *Práctica 1 y 2* → **Buscar emparejados** → tocar el ESP32.
3. Acercar y alejar la mano del sensor: el indicador y el LED cambian cada 0.5 s.

**Sin hardware (emulador):** activar **Modo simulado**. Genera las mismas
líneas que el firmware (3 s con objeto, 3 s sin objeto).

## Pruebas del docente

| Prueba | Resultado | Evidencia |
|---|---|---|
| Objeto frente al sensor → "OBJETO DETECTADO" y LED encendido | Pendiente de registrar con el circuito armado | Captura de la app + foto del LED |
| Sin objeto → "SIN OBJETO" y LED apagado | Pendiente | |
| Se corta la conexión (apagar el ESP32) | Pendiente | La app avisa "Se perdió la conexión con el ESP32" |
| Modo simulado en el emulador | Pendiente de captura | |

> Justificación: la práctica con el ESP32 ya se realizó en clase, pero al
> momento de integrarla el circuito no está armado y el teléfono físico no
> está disponible. El emulador de Android no tiene radio Bluetooth. Las filas
> pendientes se llenan cuando se arme el circuito.

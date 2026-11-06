# Práctica 1 — Comunicación IoT: ESP32, sensor infrarrojo y móvil

**Decisión: no se integra en la app BabyWolf.**

## Por qué no

BabyWolf es la app de un blog de noticias de videojuegos. Lo que hace un
lector es leer, guardar, comentar y reportar noticias. Un sensor infrarrojo
que detecta si hay un objeto frente a él, o un LED que se enciende, no
corresponde a ninguna de esas tareas, ni a las del equipo que administra el
blog.

Agregarlo sólo sería una pantalla ajena al producto, que es justo lo que se
quiso evitar: cada práctica que entró en la app lo hizo como una función real
(ver el [índice](README.md)).

Hay además dos razones técnicas:

- **Bluetooth clásico (SPP):** el firmware de la práctica usa
  `BluetoothSerial`. Flutter no lo soporta y los plugins de SPP están
  abandonados, así que habría que mantener un puente nativo en Kotlin sólo
  para esto.
- **Pruebas:** el emulador de Android no tiene radio Bluetooth. Probarlo exige
  el circuito armado y un teléfono físico.

## Qué se conserva

- La práctica se realizó en clase con el ESP32 y el sensor.
- El firmware queda en el repo como anexo: `firmware/practica1_sensor_ir/`
  (script del docente) y `firmware/iot_combinado/` (prácticas 1 y 2 juntas).
- La arquitectura IoT del ejercicio:

| Capa | Componente |
|---|---|
| Percepción | Sensor infrarrojo en GPIO 27 (LOW = objeto) |
| Procesamiento | ESP32: decide si hay objeto y enciende el LED (GPIO 2) |
| Red | Bluetooth clásico, perfil SPP, nombre `ESP32_SENSOR_IR` |
| Aplicación | Monitor serial / terminal Bluetooth del teléfono |

## Relación con el ecosistema

El ecosistema BabyWolf sí tiene un dispositivo conectado: el **wearable**,
que manda métricas de lectura al teléfono con el mismo modelo de
servicio/característica que BLE (`gatt_constants.dart`). Esa es la parte IoT
que tiene sentido para el producto, y ya existía antes de las prácticas.

La versión anterior de la app sí tenía una pantalla para esta práctica
(puente `SppBridge.kt`, modo simulado). Se retiró al integrar las prácticas
en funciones reales; sigue en el historial de git (commit `e53abb3`).

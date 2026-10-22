# Práctica 2 — Introducción al firmware: Controlador LED

**Objetivo:** firmware que lee un botón (GPIO 4, `INPUT_PULLUP`) y enciende el
LED (GPIO 2) mientras está presionado, con el estado en el monitor serial.

## Implementación

- `firmware/practica2_controlador_led/`: script del docente sin cambios.
- **Relación con la app:** esta práctica es sólo de firmware; el enunciado no
  pide interfaz móvil. Como extensión, `firmware/iot_combinado/` une las
  prácticas 1 y 2 y envía también el botón por Bluetooth. La pantalla
  *Sensor IR · ESP32* lo muestra en la tarjeta "Práctica 2 · Botón y LED".

## Interacción software ↔ hardware

| Línea del firmware | Efecto físico |
|---|---|
| `pinMode(BOTON, INPUT_PULLUP)` | Activa la resistencia interna: sin presionar, el pin lee HIGH |
| `digitalRead(BOTON) == LOW` | Al presionar, el botón conecta el pin a GND |
| `digitalWrite(LED, HIGH)` | Pone 3.3 V en GPIO 2 y el LED enciende |
| `delay(500)` | Lee 2 veces por segundo. No hay antirrebote: un toque muy corto puede no registrarse |

## Pruebas

| Prueba | Esperado | Resultado |
|---|---|---|
| Presionar el botón | LED encendido, serial: "BOTON PRESIONADO - LED ENCENDIDO" | Realizada en clase; captura pendiente |
| Soltar el botón | LED apagado, serial: "BOTON LIBERADO - LED APAGADO" | Realizada en clase; captura pendiente |
| Firmware combinado + app | La tarjeta del botón cambia en la app | Pendiente (hardware) |

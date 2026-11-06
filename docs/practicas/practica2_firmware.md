# Práctica 2 — Introducción al firmware: Controlador LED

**Decisión: no se integra en la app BabyWolf.** Es una práctica de firmware:
el enunciado no pide interfaz móvil, y un botón y un LED no tienen uso en una
app de noticias (ver la [práctica 1](practica1_iot_esp32.md)).

## Qué se conserva

- `firmware/practica2_controlador_led/`: script del docente sin cambios.
- `firmware/iot_combinado/`: une las prácticas 1 y 2 y manda también el
  estado del botón por Bluetooth.

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

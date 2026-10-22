# Firmware ESP32 — Prácticas 1 y 2

| Carpeta | Práctica | Qué hace |
|---|---|---|
| `practica1_sensor_ir/` | 1 | Script del docente: lee el sensor IR, enciende el LED y manda el estado por Bluetooth. |
| `practica2_controlador_led/` | 2 | Script del docente: botón → LED, estado en el monitor serial. |
| `iot_combinado/` | 1 + 2 | Los dos en uno, con el botón también por Bluetooth para verlo en la app. |

## Conexiones

| Componente | Pin del ESP32 |
|---|---|
| Sensor infrarrojo (p. ej. FC-51): OUT | GPIO 27 |
| Sensor infrarrojo: VCC / GND | 3V3 / GND |
| Botón: una pata | GPIO 4 |
| Botón: otra pata | GND (se usa `INPUT_PULLUP`, no lleva resistencia) |
| LED | GPIO 2 (LED integrado de la placa) |

El sensor entrega `LOW` cuando detecta un objeto; por eso el firmware
compara con `LOW`.

## Cargar y probar

1. Arduino IDE con el paquete **esp32 de Espressif**, placa *ESP32 Dev Module*.
2. `BluetoothSerial` es Bluetooth **clásico**: sólo existe en el ESP32
   original (no en ESP32-S3 ni C3, que sólo tienen BLE).
3. Monitor serial a **115200** baudios: aparecen "ESP32 listo" y las lecturas.
4. En el teléfono: Ajustes → Bluetooth → emparejar `ESP32_SENSOR_IR`.
5. App BabyWolf → 🧪 Prácticas → *Práctica 1 y 2* → **Buscar emparejados** →
   tocar `ESP32_SENSOR_IR`.

El emulador de Android no tiene radio Bluetooth: para mostrar la pantalla
sin hardware está el interruptor **Modo simulado**, que genera las mismas
líneas cada 500 ms.

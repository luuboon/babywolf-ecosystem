// Práctica 1 — Comunicación IoT mediante ESP32, sensor infrarrojo y móvil.
// Script de prueba proporcionado por el docente, sin cambios de lógica.
// La app BabyWolf lo lee en Laboratorio > Práctica 1 y 2 (Bluetooth SPP).

#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

const int sensorIR = 27;
const int led = 2;

void setup() {

  pinMode(sensorIR, INPUT);
  pinMode(led, OUTPUT);

  Serial.begin(115200);

  // Nombre que aparecerá en el teléfono
  SerialBT.begin("ESP32_SENSOR_IR");

  Serial.println("ESP32 listo");
  Serial.println("Bluetooth activo");
}

void loop() {

  int estadoSensor = digitalRead(sensorIR);

  if (estadoSensor == LOW) {

    digitalWrite(led, HIGH);

    Serial.println("OBJETO DETECTADO");
    SerialBT.println("OBJETO DETECTADO");

  } else {

    digitalWrite(led, LOW);

    Serial.println("SIN OBJETO");
    SerialBT.println("SIN OBJETO");
  }

  delay(500);
}

// Extensión de las prácticas 1 y 2 para la app BabyWolf.
//
// Une los dos scripts del docente en un solo firmware: el sensor IR
// (práctica 1) y el botón (práctica 2) se envían por Bluetooth SPP con los
// MISMOS textos, así la app los interpreta igual que en cada práctica.
// - El estado del sensor se envía cada 500 ms (igual que la práctica 1).
// - El estado del botón se envía cuando cambia, para no saturar el canal.
// - El LED se enciende si hay objeto o si el botón está presionado.

#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

const int sensorIR = 27;
const int BOTON = 4;
const int LED = 2;

int botonAnterior = -1;

void enviar(const char* texto) {
  Serial.println(texto);
  SerialBT.println(texto);
}

void setup() {
  pinMode(sensorIR, INPUT);
  pinMode(BOTON, INPUT_PULLUP);
  pinMode(LED, OUTPUT);

  Serial.begin(115200);
  SerialBT.begin("ESP32_SENSOR_IR");

  Serial.println("ESP32 listo");
  Serial.println("Bluetooth activo");
}

void loop() {
  bool hayObjeto = digitalRead(sensorIR) == LOW;
  int boton = digitalRead(BOTON);
  bool presionado = boton == LOW;

  digitalWrite(LED, (hayObjeto || presionado) ? HIGH : LOW);

  enviar(hayObjeto ? "OBJETO DETECTADO" : "SIN OBJETO");

  if (boton != botonAnterior) {
    enviar(presionado ? "BOTON PRESIONADO - LED ENCENDIDO" : "BOTON LIBERADO - LED APAGADO");
    botonAnterior = boton;
  }

  delay(500);
}

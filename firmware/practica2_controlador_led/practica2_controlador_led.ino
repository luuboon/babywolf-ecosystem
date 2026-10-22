// Práctica 2 — Introducción al firmware: Controlador LED.
// Script proporcionado por el docente, sin cambios de lógica.
// Este firmware sólo usa el monitor serial; para ver el botón en la app
// BabyWolf se usa firmware/iot_combinado.

const int LED = 2;
const int BOTON = 4;

void setup() {

  pinMode(LED, OUTPUT);
  pinMode(BOTON, INPUT_PULLUP);

  Serial.begin(115200);

  Serial.println("Firmware iniciado");
}

void loop() {
  int estadoBoton = digitalRead(BOTON);
  if (estadoBoton == LOW) {
    digitalWrite(LED, HIGH);
    Serial.println("BOTON PRESIONADO - LED ENCENDIDO");
  } else {
    digitalWrite(LED, LOW);
    Serial.println("BOTON LIBERADO - LED APAGADO");
  }
  delay(500);
}

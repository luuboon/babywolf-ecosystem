// Prácticas 1 y 2 — interpretación de lo que manda el ESP32.
//
// El firmware de la práctica 1 envía por Bluetooth una línea cada 500 ms:
//   "OBJETO DETECTADO"  o  "SIN OBJETO"
// El firmware combinado (firmware/iot_combinado) además envía el estado del
// botón de la práctica 2:
//   "BOTON PRESIONADO - LED ENCENDIDO"  o  "BOTON LIBERADO - LED APAGADO"

enum TipoLectura { sensor, boton, sistema }

class LecturaIot {
  const LecturaIot(this.tipo, this.activo, this.texto, this.hora);

  final TipoLectura tipo;

  /// sensor: hay objeto · botón: está presionado (y el LED encendido).
  final bool activo;
  final String texto;
  final DateTime hora;

  /// Normaliza mayúsculas y acentos para no depender de cómo se escribió
  /// el texto en el firmware.
  static String _normalizar(String s) => s
      .trim()
      .toUpperCase()
      .replaceAll('Ó', 'O')
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ú', 'U');

  static LecturaIot interpretar(String linea, {DateTime? hora}) {
    final t = _normalizar(linea);
    final h = hora ?? DateTime.now();
    if (t.contains('SIN OBJETO')) return LecturaIot(TipoLectura.sensor, false, linea.trim(), h);
    if (t.contains('OBJETO DETECTADO')) return LecturaIot(TipoLectura.sensor, true, linea.trim(), h);
    if (t.contains('BOTON PRESIONADO')) return LecturaIot(TipoLectura.boton, true, linea.trim(), h);
    if (t.contains('BOTON LIBERADO')) return LecturaIot(TipoLectura.boton, false, linea.trim(), h);
    return LecturaIot(TipoLectura.sistema, false, linea.trim(), h);
  }
}

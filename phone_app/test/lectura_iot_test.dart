// Prácticas 1 y 2: interpretación de las líneas del ESP32.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/laboratorio/p1_iot/lectura_iot.dart';

void main() {
  test('OBJETO DETECTADO enciende el indicador del sensor', () {
    final l = LecturaIot.interpretar('OBJETO DETECTADO\r');
    expect(l.tipo, TipoLectura.sensor);
    expect(l.activo, isTrue);
    expect(l.texto, 'OBJETO DETECTADO');
  });

  test('SIN OBJETO apaga el indicador (no se confunde con "OBJETO")', () {
    final l = LecturaIot.interpretar('SIN OBJETO');
    expect(l.tipo, TipoLectura.sensor);
    expect(l.activo, isFalse);
  });

  test('líneas del botón de la práctica 2', () {
    expect(LecturaIot.interpretar('BOTON PRESIONADO - LED ENCENDIDO').activo, isTrue);
    expect(LecturaIot.interpretar('Botón liberado - LED apagado').tipo, TipoLectura.boton);
  });

  test('mensajes de arranque del firmware se tratan como sistema', () {
    expect(LecturaIot.interpretar('ESP32 listo').tipo, TipoLectura.sistema);
  });
}

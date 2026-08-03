// Verifica que lo que el wearable escribe en una característica es exactamente
// lo que el teléfono lee. Si este test falla, las métricas llegan corruptas.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wearable_app/gatt_codec.dart';

void main() {
  test('tema activo sobrevive el viaje (UTF-8, incluye acentos)', () {
    for (final v in ['retro', 'gaming', 'tech', 'opinión']) {
      expect(GattCodec.decodeString(GattCodec.encodeString(v)), v);
    }
  });

  test('noticias sin leer sobreviven el viaje (uint16 LE)', () {
    for (final v in [0, 1, 7, 255, 256, 65535]) {
      expect(GattCodec.decodeUint16(GattCodec.encodeUint16(v)), v);
    }
  });

  test('uint16 recorta en vez de reventar fuera de rango', () {
    expect(GattCodec.decodeUint16(GattCodec.encodeUint16(70000)), 65535);
    expect(GattCodec.decodeUint16(GattCodec.encodeUint16(-5)), 0);
  });

  test('minutos de lectura sobreviven el viaje (float32 LE)', () {
    for (final v in [0.0, 0.5, 3.25, 120.75]) {
      expect(GattCodec.decodeFloat32(GattCodec.encodeFloat32(v)), v);
    }
  });

  test('un valor truncado se rechaza en vez de devolver basura', () {
    expect(() => GattCodec.decodeUint16(Uint8List.fromList([1])),
        throwsFormatException);
    expect(() => GattCodec.decodeFloat32(Uint8List.fromList([1, 2])),
        throwsFormatException);
  });
}

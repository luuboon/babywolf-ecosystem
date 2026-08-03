// Serialización de los valores de las características GATT.
//
// En BLE una característica transporta bytes crudos: no hay tipos, no hay JSON.
// Quien escribe y quien lee tienen que estar de acuerdo por contrato. Aquí vive
// ese acuerdo para las tres características de BabyWolf (string / uint16 /
// float32), y gatt_codec_test.dart lo verifica en ambos sentidos.

import 'dart:convert';
import 'dart:typed_data';

class GattCodec {
  // --- Tema activo: UTF-8 -------------------------------------------------
  static Uint8List encodeString(String v) => Uint8List.fromList(utf8.encode(v));

  static String decodeString(Uint8List b) => utf8.decode(b);

  // --- Noticias sin leer: uint16 little-endian ----------------------------
  static Uint8List encodeUint16(int v) {
    // El contrato son 2 bytes sin signo; recortamos en vez de reventar.
    final data = ByteData(2)..setUint16(0, v.clamp(0, 0xFFFF), Endian.little);
    return data.buffer.asUint8List();
  }

  static int decodeUint16(Uint8List b) {
    if (b.length < 2) throw const FormatException('uint16 requiere 2 bytes');
    return ByteData.sublistView(b).getUint16(0, Endian.little);
  }

  // --- Minutos de lectura: float32 little-endian --------------------------
  static Uint8List encodeFloat32(double v) {
    final data = ByteData(4)..setFloat32(0, v, Endian.little);
    return data.buffer.asUint8List();
  }

  static double decodeFloat32(Uint8List b) {
    if (b.length < 4) throw const FormatException('float32 requiere 4 bytes');
    return ByteData.sublistView(b).getFloat32(0, Endian.little);
  }
}

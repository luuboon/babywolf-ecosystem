// Lado periférico del GATT emulado.
//
// Un wearable BLE real anunciaría su servicio y expondría características con
// NOTIFY. El emulador Wear OS no tiene radio, así que el enlace viaja por el
// hub (ver hub/hub.dart), que reparte cada NOTIFY a los centrales suscritos.
// La forma del contrato — UUID + bytes crudos — es idéntica a la de BLE.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'gatt_constants.dart';

class GattPeripheral {
  WebSocket? _socket;
  Timer? _reintento;
  bool _detenido = false;
  final _enlace = StreamController<bool>.broadcast();

  /// Emite true cuando hay enlace con el hub, false cuando se cae.
  Stream<bool> get enlace => _enlace.stream;
  bool get conectado => _socket != null;

  Future<void> iniciar() async {
    _detenido = false;
    await _conectar();
  }

  Future<void> _conectar() async {
    try {
      _socket = await WebSocket.connect(kGattUrl);
      _enlace.add(true);
      // El periférico no espera nada de vuelta; sólo necesita enterarse
      // de que el enlace murió para reintentar.
      _socket!.listen((_) {}, onDone: _caida, onError: (_) => _caida());
    } catch (_) {
      _caida();
    }
  }

  void _caida() {
    _socket = null;
    _enlace.add(false);
    if (_detenido) return;
    _reintento?.cancel();
    _reintento = Timer(const Duration(seconds: 2), _conectar);
  }

  /// Un NOTIFY sobre la característica [charUuid]. Los bytes van en base64
  /// porque el transporte es texto; el hub no los interpreta.
  void notify(String charUuid, Uint8List valor) {
    _socket?.add(jsonEncode({'uuid': charUuid, 'bytes': base64Encode(valor)}));
  }

  Future<void> detener() async {
    _detenido = true;
    _reintento?.cancel();
    await _socket?.close();
    _socket = null;
    _enlace.add(false);
  }
}

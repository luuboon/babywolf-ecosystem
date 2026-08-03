// Lado central del GATT emulado: escanea, se conecta y se suscribe a NOTIFY.
//
// Espeja la API de un cliente BLE real (flutter_blue_plus): se escanea buscando
// un serviceUUID, y sólo llegan los valores de las características para las que
// se llamó setNotifyValue(true). El transporte va por el hub porque los
// emuladores no tienen radio Bluetooth.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'gatt_constants.dart';

enum EstadoBle { buscando, conectado, error, desconectado }

class NotificacionGatt {
  final String uuid;
  final Uint8List valor;
  const NotificacionGatt(this.uuid, this.valor);
}

/// Si el periférico deja de anunciarse por más de esto, se da por perdido.
const _timeoutAnuncio = Duration(seconds: 6);

class BleClient {
  WebSocket? _socket;
  Timer? _reintento;
  Timer? _vigilante;
  DateTime? _ultimoAnuncio;
  bool _detenido = false;

  final _suscritas = <String>{};
  final _estado = StreamController<EstadoBle>.broadcast();
  final _notificaciones = StreamController<NotificacionGatt>.broadcast();

  Stream<EstadoBle> get estado => _estado.stream;
  Stream<NotificacionGatt> get notificaciones => _notificaciones.stream;

  /// Equivale a characteristic.setNotifyValue(true): a partir de aquí llegan
  /// los valores de esa característica. Sin esto se descartan.
  void setNotifyValue(String charUuid, bool activar) {
    if (activar) {
      _suscritas.add(charUuid);
    } else {
      _suscritas.remove(charUuid);
    }
  }

  /// Empieza a buscar el periférico que anuncia [kServiceUuid].
  Future<void> escanear() async {
    _detenido = false;
    _estado.add(EstadoBle.buscando);
    await _conectar();

    _vigilante?.cancel();
    _vigilante = Timer.periodic(const Duration(seconds: 2), (_) {
      final visto = _ultimoAnuncio;
      if (visto == null) return;
      if (DateTime.now().difference(visto) > _timeoutAnuncio) {
        // El wearable dejó de anunciarse: se cayó o lo cerraron.
        _ultimoAnuncio = null;
        _estado.add(EstadoBle.desconectado);
      }
    });
  }

  Future<void> _conectar() async {
    try {
      _socket = await WebSocket.connect(kGattUrl);
      _estado.add(EstadoBle.buscando); // Hay medio, falta encontrar el servicio.
      _socket!.listen(_recibir, onDone: _caida, onError: (_) => _caida());
    } catch (_) {
      // Sin hub no hay medio físico: es el equivalente a Bluetooth apagado.
      _estado.add(EstadoBle.error);
      _programarReintento();
    }
  }

  void _recibir(dynamic raw) {
    if (raw is! String) return;

    final Object? msg;
    try {
      msg = jsonDecode(raw);
    } catch (_) {
      return; // Trama corrupta.
    }
    if (msg is! Map || msg['uuid'] is! String || msg['bytes'] is! String) return;

    final uuid = msg['uuid'] as String;
    final Uint8List valor;
    try {
      valor = base64Decode(msg['bytes'] as String);
    } catch (_) {
      return;
    }

    // El anuncio del servicio es lo que nos dice que el wearable sigue vivo.
    if (uuid == kServiceUuid) {
      final primera = _ultimoAnuncio == null;
      _ultimoAnuncio = DateTime.now();
      if (primera) _estado.add(EstadoBle.conectado);
      return;
    }

    if (_suscritas.contains(uuid)) {
      _notificaciones.add(NotificacionGatt(uuid, valor));
    }
  }

  void _caida() {
    _socket = null;
    _ultimoAnuncio = null;
    _estado.add(EstadoBle.desconectado);
    _programarReintento();
  }

  void _programarReintento() {
    if (_detenido) return;
    _reintento?.cancel();
    _reintento = Timer(const Duration(seconds: 2), _conectar);
  }

  Future<void> detener() async {
    _detenido = true;
    _reintento?.cancel();
    _vigilante?.cancel();
    await _socket?.close();
    _socket = null;
    _estado.add(EstadoBle.desconectado);
  }
}

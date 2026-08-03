// Acumula lo que llega del wearable por GATT y lo publica a la UI.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble_client.dart';
import '../gatt_codec.dart';
import '../gatt_constants.dart';

class ActivityProvider extends ChangeNotifier {
  final BleClient _ble;
  StreamSubscription<EstadoBle>? _subEstado;
  StreamSubscription<NotificacionGatt>? _subNotif;

  EstadoBle estado = EstadoBle.desconectado;
  String? temaActivo;
  int sinLeer = 0;
  double minutos = 0;
  int lecturas = 0;
  DateTime? ultimaLectura;

  ActivityProvider([BleClient? ble]) : _ble = ble ?? BleClient();

  /// Umbral crítico del caso de estudio: demasiadas noticias sin leer.
  bool get alertaCritica => sinLeer > kUmbralNoticiasSinLeer;

  String get textoEstado => switch (estado) {
        EstadoBle.buscando => 'Buscando wearable…',
        EstadoBle.conectado => 'Wearable conectado',
        EstadoBle.error => 'Sin enlace: ¿está corriendo el hub?',
        EstadoBle.desconectado => 'Wearable desconectado',
      };

  Future<void> iniciar() async {
    _subEstado = _ble.estado.listen((e) {
      estado = e;
      notifyListeners();
    });
    _subNotif = _ble.notificaciones.listen(_procesar);

    // Suscripción NOTIFY a cada característica del servicio.
    _ble.setNotifyValue(kCharTemaActivo, true);
    _ble.setNotifyValue(kCharNoticiasSinLeer, true);
    _ble.setNotifyValue(kCharMinutosLectura, true);

    await _ble.escanear();
  }

  /// Los bytes no llevan tipo: el UUID de la característica dice cómo leerlos.
  void _procesar(NotificacionGatt n) {
    try {
      switch (n.uuid) {
        case kCharTemaActivo:
          temaActivo = GattCodec.decodeString(n.valor);
        case kCharNoticiasSinLeer:
          sinLeer = GattCodec.decodeUint16(n.valor);
        case kCharMinutosLectura:
          minutos = GattCodec.decodeFloat32(n.valor);
        default:
          return; // Característica que no nos interesa.
      }
    } on FormatException {
      return; // Valor truncado: mejor ignorarlo que mostrar basura.
    }

    lecturas++;
    ultimaLectura = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _subEstado?.cancel();
    _subNotif?.cancel();
    _ble.detener();
    super.dispose();
  }
}

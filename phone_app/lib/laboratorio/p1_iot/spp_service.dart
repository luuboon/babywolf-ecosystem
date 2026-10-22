// Lado Flutter del puente Bluetooth clásico (ver android/.../SppBridge.kt).

import 'package:flutter/services.dart';

class DispositivoBt {
  const DispositivoBt(this.nombre, this.direccion);
  final String nombre;
  final String direccion;
}

class SppException implements Exception {
  const SppException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Marca que el puente nativo envía cuando se corta la conexión.
const kSppDesconectado = '__DESCONECTADO__';

class SppService {
  static const _metodos = MethodChannel('babywolf/spp');
  static const _eventos = EventChannel('babywolf/spp/lineas');

  Stream<String>? _lineas;

  /// Cada línea que llega del ESP32.
  Stream<String> get lineas =>
      _lineas ??= _eventos.receiveBroadcastStream().map((e) => '$e');

  /// sin_bluetooth | sin_permiso | apagado | listo | conectado
  Future<String> estado() async {
    try {
      return await _metodos.invokeMethod<String>('estado') ?? 'sin_bluetooth';
    } on MissingPluginException {
      return 'sin_bluetooth'; // iOS, escritorio o pruebas
    } on PlatformException {
      return 'sin_bluetooth';
    }
  }

  /// Dispositivos ya emparejados en los ajustes del teléfono.
  Future<List<DispositivoBt>> emparejados() async {
    try {
      final lista = await _metodos.invokeListMethod<dynamic>('emparejados') ?? const [];
      return [
        for (final e in lista)
          if (e is Map) DispositivoBt('${e['nombre']}', '${e['direccion']}'),
      ];
    } on PlatformException catch (e) {
      throw SppException(e.message ?? 'No fue posible leer los dispositivos.');
    } on MissingPluginException {
      throw const SppException('Este dispositivo no tiene Bluetooth clásico.');
    }
  }

  Future<void> conectar(String direccion) async {
    try {
      await _metodos.invokeMethod<bool>('conectar', {'direccion': direccion});
    } on PlatformException catch (e) {
      throw SppException(e.message ?? 'No fue posible conectar.');
    } on MissingPluginException {
      throw const SppException('Este dispositivo no tiene Bluetooth clásico.');
    }
  }

  Future<void> desconectar() async {
    try {
      await _metodos.invokeMethod<void>('desconectar');
    } on MissingPluginException {
      // Nada que cerrar.
    } on PlatformException {
      // Nada que cerrar.
    }
  }
}

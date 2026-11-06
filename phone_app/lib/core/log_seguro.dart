// Práctica 5 (AccesoSeguro) — Actividad de la cuenta sin datos sensibles.
//
// Regla: nada de lo que se registra puede incluir la contraseña ni el token.
// Por diseño este registro NO tiene ningún parámetro para recibirlos, y el
// correo se guarda enmascarado. En compilaciones release no se imprime nada
// en Logcat. La pantalla Cuenta muestra los últimos eventos al usuario.

import 'package:flutter/foundation.dart';

class EventoSeguro {
  const EventoSeguro(this.hora, this.texto);
  final DateTime hora;
  final String texto;
}

class LogSeguro {
  LogSeguro._();

  static final List<EventoSeguro> _eventos = [];

  /// Copia de lo registrado, para mostrarlo en pantalla como evidencia.
  static List<EventoSeguro> get eventos => List.unmodifiable(_eventos);

  /// "abraham@gmail.com" → "a***m@gmail.com". Suficiente para reconocer la
  /// cuenta propia, inútil para alguien que lea el Logcat.
  static String enmascarar(String correo) {
    final c = correo.trim();
    if (c.isEmpty) return '(vacío)';
    final arroba = c.indexOf('@');
    final local = arroba < 0 ? c : c.substring(0, arroba);
    final dominio = arroba < 0 ? '' : c.substring(arroba);
    final oculto = local.length <= 2 ? '***' : '${local[0]}***${local[local.length - 1]}';
    return '$oculto$dominio';
  }

  static void registrar(String evento, {String? correo}) {
    final texto = correo == null ? evento : '$evento · ${enmascarar(correo)}';
    _eventos.insert(0, EventoSeguro(DateTime.now(), texto));
    if (_eventos.length > 30) _eventos.removeLast();
    if (kDebugMode) debugPrint('[Cuenta] $texto');
  }

  @visibleForTesting
  static void limpiar() => _eventos.clear();
}

// Práctica 5 — Registro de eventos sin datos sensibles.
//
// Regla: nada de lo que se registra puede incluir la contraseña. Por diseño
// este registro NO tiene ningún parámetro para recibirla, y el usuario se
// guarda enmascarado. En compilaciones release no se imprime nada en Logcat.

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

  /// "alumno.uteq" → "a***q (11)". Suficiente para depurar, inútil para
  /// alguien que lea el Logcat.
  static String enmascarar(String usuario) {
    final u = usuario.trim();
    if (u.isEmpty) return '(vacío)';
    if (u.length <= 2) return '*** (${u.length})';
    return '${u[0]}***${u[u.length - 1]} (${u.length})';
  }

  static void registrar(String evento, {String? usuario}) {
    final texto = usuario == null ? evento : '$evento · usuario=${enmascarar(usuario)}';
    _eventos.insert(0, EventoSeguro(DateTime.now(), texto));
    if (_eventos.length > 30) _eventos.removeLast();
    if (kDebugMode) debugPrint('[AccesoSeguro] $texto');
  }

  @visibleForTesting
  static void limpiar() => _eventos.clear();
}

// Práctica 5 — Validación de entradas y verificación de credenciales.

import 'dart:convert';

import 'package:crypto/crypto.dart';

class ValidadorAcceso {
  static const maxUsuario = 30;
  static const minContrasena = 8;
  static const maxContrasena = 64;

  static final _usuarioPermitido = RegExp(r'^[a-zA-Z0-9._-]+$');

  /// null = válido. Los mensajes describen la regla, no datos del sistema.
  static String? usuario(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Escribe tu usuario';
    if (v.trim().isEmpty) return 'El usuario no puede contener solo espacios';
    if (v.trim().length > maxUsuario) return 'Máximo $maxUsuario caracteres';
    if (!_usuarioPermitido.hasMatch(v.trim())) {
      return 'Usa solo letras, números, punto, guion o guion bajo';
    }
    return null;
  }

  /// La contraseña NO se recorta: los espacios cuentan como caracteres.
  static String? contrasena(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Escribe tu contraseña';
    if (v.length < minContrasena) return 'La contraseña debe tener al menos $minContrasena caracteres';
    if (v.length > maxContrasena) return 'Máximo $maxContrasena caracteres';
    return null;
  }
}

/// Credenciales de prueba del acceso simulado. Se guarda el hash SHA-256 de
/// la contraseña, no la contraseña: aunque alguien descompile la app no la
/// lee en texto plano. (Los datos de prueba están en docs/practicas.)
class CredencialesPrueba {
  static const usuario = 'alumno.uteq';

  /// SHA-256 de la contraseña de prueba (ver docs/practicas/practica5_acceso_seguro.md).
  static const hashContrasena = 'f906cf1535e28e40228f75be9826e82e341b15014e4a8a49fe02c3ca9ad0027a';

  static List<int> hash(String texto) => sha256.convert(utf8.encode(texto)).bytes;

  static List<int> _hex(String h) => [
        for (var i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16),
      ];

  /// Comparación en tiempo constante: no se corta en el primer byte
  /// distinto, así el tiempo de respuesta no da pistas.
  static bool _iguales(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var dif = 0;
    for (var i = 0; i < a.length; i++) {
      dif |= a[i] ^ b[i];
    }
    return dif == 0;
  }

  static bool verificar(String usuario, String contrasena) {
    final okUsuario = usuario.trim().toLowerCase() == CredencialesPrueba.usuario;
    final okContrasena = _iguales(hash(contrasena), _hex(hashContrasena));
    return okUsuario && okContrasena;
  }
}

/// Bloqueo temporal tras varios intentos fallidos (frena la fuerza bruta).
class LimiteIntentos {
  LimiteIntentos({this.maximo = 5, this.espera = const Duration(seconds: 30), DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final int maximo;
  final Duration espera;
  final DateTime Function() _reloj;
  int _fallos = 0;
  DateTime? _hasta;

  int get fallos => _fallos;

  Duration? get bloqueoRestante {
    final h = _hasta;
    if (h == null) return null;
    final r = h.difference(_reloj());
    if (r.isNegative) {
      _hasta = null;
      _fallos = 0;
      return null;
    }
    return r;
  }

  void fallo() {
    _fallos++;
    if (_fallos >= maximo) _hasta = _reloj().add(espera);
  }

  void exito() {
    _fallos = 0;
    _hasta = null;
  }
}

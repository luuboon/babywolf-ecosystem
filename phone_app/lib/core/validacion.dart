// Práctica 5 (AccesoSeguro) — Validación de entradas del inicio de sesión y
// del registro, y freno a la fuerza bruta.
//
// La app valida antes de mandar nada a Supabase. Los mensajes describen la
// regla que no se cumple, nunca datos del sistema (si el correo existe, etc.).

class Validar {
  Validar._();

  static const maxCorreo = 120;
  static const minContrasenaNueva = 8;
  static const maxContrasena = 72; // límite de bcrypt en Supabase Auth
  static const minApodo = 3;
  static const maxApodo = 20;

  static final _correo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _apodo = RegExp(r'^[a-zA-Z0-9._-]+$');

  /// null = válido.
  static String? correo(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'Escribe tu correo';
    if (v.length > maxCorreo) return 'Máximo $maxCorreo caracteres';
    if (!_correo.hasMatch(v)) return 'Escribe un correo válido (nombre@dominio.com)';
    return null;
  }

  /// Contraseña al INICIAR sesión: sólo se revisa que exista y no exceda el
  /// límite. No se recorta: los espacios cuentan.
  static String? contrasena(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Escribe tu contraseña';
    if (v.length > maxContrasena) return 'Máximo $maxContrasena caracteres';
    return null;
  }

  /// Contraseña al CREAR la cuenta: mínimo 8, con letras y números.
  static String? contrasenaNueva(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Escribe una contraseña';
    if (v.length < minContrasenaNueva) return 'Debe tener al menos $minContrasenaNueva caracteres';
    if (v.length > maxContrasena) return 'Máximo $maxContrasena caracteres';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) {
      return 'Combina letras y números';
    }
    return null;
  }

  static String? apodo(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'Escribe un nombre de usuario';
    if (v.length < minApodo) return 'Mínimo $minApodo caracteres';
    if (v.length > maxApodo) return 'Máximo $maxApodo caracteres';
    if (!_apodo.hasMatch(v)) return 'Usa solo letras, números, punto, guion o guion bajo';
    return null;
  }
}

/// Bloqueo temporal tras varios intentos fallidos (frena la fuerza bruta).
/// Vive en la sesión de la app, no en la pantalla: salir y volver a entrar a
/// la pantalla no reinicia la cuenta.
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

// Cuenta de BabyWolf en el teléfono (Prácticas 5 y 10).
//
// Es la MISMA cuenta de la web: Supabase Auth con correo y contraseña. Todo lo
// que el lector hace con su cuenta (comentar, reportar, la mesa de ayuda del
// admin) pide el token aquí.
//
// Seguridad (Práctica 5):
// - La contraseña sólo viaja por HTTPS a Supabase; no se guarda en ningún lado.
// - Se guarda únicamente el refresh token, en el almacenamiento cifrado del
//   sistema (Android Keystore), para seguir dentro al reabrir la app.
// - El access token dura 1 hora y se renueva solo antes de vencer.
// - Errores genéricos: nunca se dice si el correo existe.
// - 5 fallos seguidos bloquean el formulario 30 s (LimiteIntentos).

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'log_seguro.dart';
import 'supabase.dart';
import 'validacion.dart';

class Cuenta {
  const Cuenta({required this.uid, required this.correo, required this.apodo, required this.rol});

  final String uid;
  final String correo;
  final String apodo;
  final String rol; // 'user' | 'admin' (tabla public.users del blog)

  bool get esAdmin => rol == 'admin';
}

class AuthFallo implements Exception {
  const AuthFallo(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Dónde se guarda el refresh token entre aperturas de la app.
abstract class AlmacenSesion {
  Future<String?> leer();
  Future<void> guardar(String refreshToken);
  Future<void> borrar();
}

class AlmacenSeguro implements AlmacenSesion {
  static const _clave = 'bw_refresh_token';
  final _s = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  @override
  Future<String?> leer() => _s.read(key: _clave);

  @override
  Future<void> guardar(String refreshToken) => _s.write(key: _clave, value: refreshToken);

  @override
  Future<void> borrar() => _s.delete(key: _clave);
}

/// Para pruebas: guarda en memoria.
class AlmacenMemoria implements AlmacenSesion {
  String? valor;

  @override
  Future<String?> leer() async => valor;

  @override
  Future<void> guardar(String refreshToken) async => valor = refreshToken;

  @override
  Future<void> borrar() async => valor = null;
}

class Sesion extends ChangeNotifier {
  Sesion({http.Client? cliente, AlmacenSesion? almacen, DateTime Function()? reloj, LimiteIntentos? limite})
      : _c = cliente ?? http.Client(),
        _almacen = almacen ?? AlmacenSeguro(),
        _reloj = reloj ?? DateTime.now,
        limite = limite ?? LimiteIntentos(reloj: reloj);

  final http.Client _c;
  final AlmacenSesion _almacen;
  final DateTime Function() _reloj;
  final LimiteIntentos limite;

  Cuenta? _cuenta;
  String? _access;
  String? _refresh;
  DateTime? _expira;
  bool _listo = false;
  Future<void>? _renovando;

  Cuenta? get cuenta => _cuenta;
  bool get activa => _cuenta != null;
  bool get esAdmin => _cuenta?.esAdmin ?? false;

  /// false mientras se intenta recuperar la sesión guardada al abrir la app.
  bool get listo => _listo;

  // ── Abrir la app ──────────────────────────────────────────

  Future<void> restaurar() async {
    try {
      final r = await _almacen.leer();
      if (r != null) await _renovar(r);
    } on SinConexion {
      // Sin red: se conserva el refresh token guardado para la próxima vez.
    } on AuthFallo {
      // El refresh token ya no sirve (se cerró sesión en otro lado, etc.).
    } catch (_) {
      // Almacenamiento ilegible: se empieza sin sesión.
    }
    _listo = true;
    notifyListeners();
  }

  // ── Entrar, crear cuenta, salir ───────────────────────────

  Future<void> entrar(String correo, String contrasena) async {
    final espera = limite.bloqueoRestante;
    if (espera != null) {
      throw AuthFallo('Demasiados intentos. Espera ${espera.inSeconds + 1} s.');
    }
    final invalido = Validar.correo(correo) ?? Validar.contrasena(contrasena);
    if (invalido != null) {
      LogSeguro.registrar('validacion_rechazada');
      throw AuthFallo(invalido);
    }

    final http.Response r;
    try {
      r = await Supabase.enviar(
        _c,
        Supabase.peticion('POST', Supabase.auth('token', {'grant_type': 'password'}),
            cuerpo: {'email': correo.trim(), 'password': contrasena}),
      );
    } on SinConexion {
      // Sin red no cuenta como intento fallido: no se probó nada.
      throw const AuthFallo('Sin conexión. Revisa tu internet e inténtalo de nuevo.');
    }

    if (r.statusCode == 200) {
      await _aplicar(Supabase.json(r));
      limite.exito();
      LogSeguro.registrar('inicio_sesion', correo: correo);
      return;
    }
    if (r.statusCode == 429) {
      throw const AuthFallo('Demasiados intentos en el servidor. Espera unos minutos.');
    }
    limite.fallo();
    LogSeguro.registrar('inicio_fallido', correo: correo);
    // Mismo mensaje para correo inexistente, contraseña mala o cuenta sin
    // confirmar: no se revela qué cuentas existen.
    throw const AuthFallo('Correo o contraseña incorrectos.');
  }

  /// true = la cuenta quedó con sesión iniciada; false = Supabase pidió
  /// confirmar el correo antes de entrar.
  Future<bool> registrarse(String apodo, String correo, String contrasena) async {
    final invalido = Validar.apodo(apodo) ?? Validar.correo(correo) ?? Validar.contrasenaNueva(contrasena);
    if (invalido != null) throw AuthFallo(invalido);

    final http.Response r;
    try {
      r = await Supabase.enviar(
        _c,
        Supabase.peticion('POST', Supabase.auth('signup'), cuerpo: {
          'email': correo.trim(),
          'password': contrasena,
          'data': {'username': apodo.trim()},
        }),
      );
    } on SinConexion {
      throw const AuthFallo('Sin conexión. Revisa tu internet e inténtalo de nuevo.');
    }

    if (r.statusCode == 200) {
      final j = Supabase.json(r);
      LogSeguro.registrar('cuenta_creada', correo: correo);
      if (j is Map && j['access_token'] is String) {
        await _aplicar(j);
        return true;
      }
      return false;
    }
    if (r.statusCode == 429) {
      throw const AuthFallo('Se crearon demasiadas cuentas seguidas. Espera unos minutos.');
    }
    // El trigger del blog guarda el nombre de usuario como único: si ya
    // existe, Supabase responde 500. No se dice cuál de los dos datos chocó.
    throw const AuthFallo('No se pudo crear la cuenta. Prueba con otro correo o nombre de usuario.');
  }

  Future<void> salir() async {
    final token = _access;
    final correo = _cuenta?.correo;
    if (token != null) {
      try {
        await Supabase.enviar(_c, Supabase.peticion('POST', Supabase.auth('logout'), token: token));
      } catch (_) {
        // Sin red: igual se borra la sesión del teléfono.
      }
    }
    await _limpiar();
    LogSeguro.registrar('cierre_sesion', correo: correo);
  }

  // ── Token para las demás pantallas ────────────────────────

  /// Access token vigente. Lo renueva si le queda menos de 1 minuto.
  Future<String> token() async {
    final refresh = _refresh;
    if (_access == null || refresh == null) {
      throw const AuthFallo('Inicia sesión para continuar.');
    }
    final exp = _expira;
    if (exp != null && exp.difference(_reloj()) < const Duration(minutes: 1)) {
      await (_renovando ??= _renovar(refresh).whenComplete(() => _renovando = null));
    }
    return _access!;
  }

  /// Para las lecturas públicas (comentarios): token si hay sesión, si no null.
  Future<String?> tokenOpcional() async {
    if (!activa) return null;
    try {
      return await token();
    } on AuthFallo {
      return null;
    }
  }

  // ── Interno ───────────────────────────────────────────────

  Future<void> _renovar(String refresh) async {
    final r = await Supabase.enviar(
      _c,
      Supabase.peticion('POST', Supabase.auth('token', {'grant_type': 'refresh_token'}),
          cuerpo: {'refresh_token': refresh}),
    );
    if (r.statusCode != 200) {
      await _limpiar();
      throw const AuthFallo('Tu sesión venció. Vuelve a iniciar sesión.');
    }
    await _aplicar(Supabase.json(r));
  }

  Future<void> _aplicar(dynamic j) async {
    if (j is! Map || j['access_token'] is! String || j['refresh_token'] is! String) {
      throw const AuthFallo('Respuesta inesperada del servidor.');
    }
    _access = j['access_token'] as String;
    _refresh = j['refresh_token'] as String;
    final dura = (j['expires_in'] as num?)?.toInt() ?? 3600;
    _expira = _reloj().add(Duration(seconds: dura));

    final u = j['user'] is Map ? j['user'] as Map : const {};
    final uid = u['id'] as String? ?? '';
    final correo = u['email'] as String? ?? '';
    final meta = u['user_metadata'] is Map ? u['user_metadata'] as Map : const {};
    var apodo = (meta['username'] as String?) ?? correo.split('@').first;
    var rol = 'user';

    // Rol y nombre de usuario desde la tabla del blog: es la misma fuente
    // que usa la web para decidir quién es admin.
    try {
      final r = await Supabase.enviar(
        _c,
        Supabase.peticion('GET', Supabase.rest('users', {'select': 'username,role', 'id': 'eq.$uid'}),
            token: _access),
      );
      final filas = Supabase.json(r);
      if (r.statusCode == 200 && filas is List && filas.isNotEmpty && filas.first is Map) {
        final f = filas.first as Map;
        apodo = f['username'] as String? ?? apodo;
        rol = f['role'] as String? ?? rol;
      }
    } on SinConexion {
      // Se queda con los datos del token; el rol se vuelve a leer al renovar.
    }

    _cuenta = Cuenta(uid: uid, correo: correo, apodo: apodo, rol: rol);
    await _almacen.guardar(_refresh!);
    notifyListeners();
  }

  Future<void> _limpiar() async {
    _cuenta = null;
    _access = null;
    _refresh = null;
    _expira = null;
    try {
      await _almacen.borrar();
    } catch (_) {}
    notifyListeners();
  }
}

// Práctica 10 — Autenticación (Supabase Auth) y acceso directo a la tabla
// incidencias (API REST de Supabase) con el JWT del usuario.
//
// La app NO filtra nada por su cuenta: manda la petición tal cual y es la
// base (reglas RLS de 006_incidencias_rls.sql) la que acepta o rechaza. Así
// se demuestra que lo no autorizado se rechaza en el servidor y no sólo se
// oculta en la interfaz.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../p7_soporte/supabase_login.dart' show SupabaseLogin;

class SesionSupabase {
  const SesionSupabase({required this.token, required this.uid, required this.email});
  final String token;
  final String uid;
  final String email;

  /// El UID también viene dentro del JWT (claim "sub"). Se lee para
  /// comprobar que coincide con el que devuelve Supabase Auth.
  static String? uidDelToken(String jwt) {
    final partes = jwt.split('.');
    if (partes.length != 3) return null;
    try {
      final datos = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))));
      return datos is Map ? datos['sub'] as String? : null;
    } catch (_) {
      return null;
    }
  }
}

class Incidencia {
  const Incidencia({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.creadoPor,
    required this.creada,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String estado;
  final String creadoPor;
  final DateTime? creada;

  factory Incidencia.desdeJson(Map<String, dynamic> j) => Incidencia(
        id: j['id'] as String? ?? '',
        titulo: j['titulo'] as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
        estado: j['estado'] as String? ?? 'abierta',
        creadoPor: j['creado_por'] as String? ?? '',
        creada: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

/// Resultado de una operación tal como la contestó la base.
class Resultado {
  const Resultado({
    required this.permitido,
    required this.codigo,
    required this.filas,
    required this.detalle,
    this.datos = const [],
  });

  final bool permitido;
  final int codigo; // HTTP; 0 = sin conexión
  final int filas; // filas devueltas o afectadas
  final String detalle;
  final List<Map<String, dynamic>> datos;

  /// Cómo contesta Postgres a algo no autorizado:
  /// - permiso de tabla (sin sesión) o fila nueva que viola una regla →
  ///   error 401/403 con código 42501;
  /// - leer, cambiar o borrar filas ajenas → 200 con 0 filas: para RLS esas
  ///   filas "no existen" para ese usuario, así que no hay nada que tocar.
  static Resultado desdeRespuesta(int codigo, String cuerpo) {
    dynamic j;
    try {
      j = cuerpo.isEmpty ? null : jsonDecode(cuerpo);
    } on FormatException {
      j = null;
    }
    if (codigo >= 200 && codigo < 300) {
      final filas = j is List ? j.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
      return Resultado(
        permitido: filas.isNotEmpty,
        codigo: codigo,
        filas: filas.length,
        detalle: filas.isEmpty ? 'La base no devolvió ni afectó ninguna fila (RLS).' : '${filas.length} fila(s).',
        datos: filas,
      );
    }
    var mensaje = 'HTTP $codigo';
    if (j is Map) {
      final partes = [j['code'], j['message'] ?? j['msg'] ?? j['error_description'] ?? j['error']]
          .where((e) => e != null && '$e'.isNotEmpty)
          .join(' · ');
      if (partes.isNotEmpty) mensaje = '$codigo · $partes';
    }
    return Resultado(permitido: false, codigo: codigo, filas: 0, detalle: mensaje);
  }

  static const sinConexion =
      Resultado(permitido: false, codigo: 0, filas: 0, detalle: 'Sin conexión con Supabase.');
}

class IncidenciasApi {
  IncidenciasApi({http.Client? cliente}) : _c = cliente ?? http.Client();

  final http.Client _c;
  static const _timeout = Duration(seconds: 15);
  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static bool esUuid(String s) => _uuid.hasMatch(s.trim());

  // ── Autenticación ─────────────────────────────────────────

  /// SEG-01 / SEG-02. Error genérico: no se dice si falló el correo o la
  /// contraseña.
  Future<SesionSupabase> entrar(String email, String contrasena) async {
    final http.Response r;
    try {
      r = await _c
          .post(
            Uri.parse('${SupabaseLogin.url}/auth/v1/token?grant_type=password'),
            headers: {'apikey': SupabaseLogin.anonKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': contrasena}),
          )
          .timeout(_timeout);
    } on SocketException {
      throw const AuthException('Sin conexión con Supabase.');
    } on TimeoutException {
      throw const AuthException('Supabase no respondió a tiempo.');
    } on http.ClientException {
      throw const AuthException('Sin conexión con Supabase.');
    }
    final j = r.statusCode == 200 ? jsonDecode(utf8.decode(r.bodyBytes)) : null;
    if (j is! Map || j['access_token'] is! String) {
      throw const AuthException('Correo o contraseña incorrectos.');
    }
    final token = j['access_token'] as String;
    final user = j['user'];
    final uid = (user is Map ? user['id'] as String? : null) ?? SesionSupabase.uidDelToken(token) ?? '';
    final correo = (user is Map ? user['email'] as String? : null) ?? email.trim();
    return SesionSupabase(token: token, uid: uid, email: correo);
  }

  /// Cierra la sesión en Supabase (invalida el refresh token). El JWT
  /// actual se descarta en la app.
  Future<void> salir(SesionSupabase s) async {
    try {
      await _c.post(Uri.parse('${SupabaseLogin.url}/auth/v1/logout'), headers: {
        'apikey': SupabaseLogin.anonKey,
        'Authorization': 'Bearer ${s.token}',
      }).timeout(_timeout);
    } catch (_) {
      // Sin red: igual se borra la sesión local.
    }
  }

  // ── Tabla incidencias ─────────────────────────────────────

  /// token null = petición SIN sesión (sólo la llave pública), para SEG-10.
  Future<Resultado> _rest(String metodo, String query, {String? token, Object? cuerpo}) async {
    final uri = Uri.parse('${SupabaseLogin.url}/rest/v1/incidencias$query');
    final req = http.Request(metodo, uri)
      ..headers.addAll({
        'apikey': SupabaseLogin.anonKey,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (cuerpo != null) req.body = jsonEncode(cuerpo);
    try {
      final r = await http.Response.fromStream(await _c.send(req).timeout(_timeout));
      return Resultado.desdeRespuesta(r.statusCode, utf8.decode(r.bodyBytes));
    } on SocketException {
      return Resultado.sinConexion;
    } on TimeoutException {
      return Resultado.sinConexion;
    } on http.ClientException {
      return Resultado.sinConexion;
    }
  }

  String _id(String id) => 'id=eq.${Uri.encodeQueryComponent(id.trim())}';

  Future<Resultado> listar(String? token) => _rest('GET', '?select=*&order=created_at.desc', token: token);

  Future<Resultado> leer(String? token, String id) => _rest('GET', '?select=*&${_id(id)}', token: token);

  /// Fase 2: el propietario se manda explícito. Para SEG-04 se manda un UID
  /// ajeno a propósito.
  Future<Resultado> crear(String? token, {required String titulo, required String descripcion, required String creadoPor}) =>
      _rest('POST', '', token: token, cuerpo: {
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
        'creado_por': creadoPor.trim(),
      });

  Future<Resultado> cambiarEstado(String? token, String id, String estado) =>
      _rest('PATCH', '?${_id(id)}', token: token, cuerpo: {'estado': estado});

  Future<Resultado> cambiarPropietario(String? token, String id, String nuevoUid) =>
      _rest('PATCH', '?${_id(id)}', token: token, cuerpo: {'creado_por': nuevoUid.trim()});

  Future<Resultado> eliminar(String? token, String id) => _rest('DELETE', '?${_id(id)}', token: token);
}

class AuthException implements Exception {
  const AuthException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

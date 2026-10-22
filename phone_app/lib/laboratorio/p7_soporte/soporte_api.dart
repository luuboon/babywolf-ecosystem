// Práctica 7 — Cliente HTTP de la mesa de ayuda (/api/soporte/*).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../services/blog_api.dart';
import 'modelos.dart';

class SoporteException implements Exception {
  const SoporteException(this.mensaje, {this.codigo = 0, this.campos = const {}, this.sinConexion = false});

  final String mensaje;
  final int codigo;
  final Map<String, String> campos;

  /// true = no hubo respuesta del servidor (TC07): la operación puede
  /// guardarse como pendiente y reintentarse.
  final bool sinConexion;

  @override
  String toString() => mensaje;
}

class Sesion {
  const Sesion(this.token, this.yo);
  final String token;
  final Participante yo;
}

class EstadoMesa {
  const EstadoMesa(this.yo, this.rolEfectivo, this.participantes);
  final Participante yo;
  final String rolEfectivo;
  final List<Participante> participantes;
}

class InfoInvitacion {
  const InfoInvitacion(this.rol, this.nombre, this.expira, this.usada);
  final String rol;
  final String nombre;
  final DateTime? expira;
  final bool usada;
}

class SoporteApi {
  SoporteApi({http.Client? cliente, String? base})
      : _c = cliente ?? http.Client(),
        _base = base ?? BlogApi.base;

  final http.Client _c;
  final String _base;
  String? token;
  static const _timeout = Duration(seconds: 12);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'X-Soporte-Token': token!,
      };

  Future<dynamic> _pedir(String metodo, String ruta, {Object? cuerpo, Uri? url, Map<String, String>? extra}) async {
    final uri = url ?? Uri.parse('$_base$ruta');
    final req = http.Request(metodo, uri)..headers.addAll({..._headers, ...?extra});
    if (cuerpo != null) req.body = jsonEncode(cuerpo);
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _c.send(req).timeout(_timeout));
    } on SocketException {
      throw const SoporteException('Sin conexión con el servidor.', sinConexion: true);
    } on TimeoutException {
      throw const SoporteException('El servidor no respondió a tiempo.', sinConexion: true);
    } on http.ClientException {
      throw const SoporteException('Sin conexión con el servidor.', sinConexion: true);
    }
    final texto = utf8.decode(r.bodyBytes);
    final datos = texto.isEmpty ? null : _json(texto);
    if (r.statusCode >= 200 && r.statusCode < 300) return datos;

    var mensaje = 'No fue posible completar la operación.';
    final campos = <String, String>{};
    if (datos is Map) {
      if (datos['error'] is String) mensaje = datos['error'] as String;
      final c = datos['campos'];
      if (c is Map) c.forEach((k, v) => campos['$k'] = '$v');
    }
    throw SoporteException(mensaje, codigo: r.statusCode, campos: campos);
  }

  static dynamic _json(String t) {
    try {
      return jsonDecode(t);
    } on FormatException {
      return null;
    }
  }

  Sesion _sesion(dynamic j) {
    final m = j as Map<String, dynamic>;
    token = m['token'] as String;
    return Sesion(token!, Participante.desdeJson(m['participante'] as Map<String, dynamic>));
  }

  // ── Entrar ──────────────────────────────────────────────────

  /// El admin abre su sesión con el JWT de su cuenta del blog (Supabase).
  Future<Sesion> sesionAdmin(String jwtSupabase, String dispositivo) async {
    final j = await _pedir('POST', '/admin/soporte/sesion',
        cuerpo: {'dispositivo': dispositivo}, extra: {'Authorization': 'Bearer $jwtSupabase'});
    return _sesion(j);
  }

  static Uri? urlInvitacion(String texto) {
    final u = Uri.tryParse(texto.trim());
    if (u == null || !u.hasScheme || !u.path.endsWith('/api/soporte/unirse')) return null;
    if (!u.queryParameters.containsKey('sig')) return null;
    return u;
  }

  Future<InfoInvitacion> verInvitacion(Uri url) async {
    final j = await _pedir('GET', '', url: url) as Map<String, dynamic>;
    return InfoInvitacion(
      j['rol'] as String? ?? '',
      j['nombre'] as String? ?? '',
      DateTime.tryParse(j['expira'] as String? ?? ''),
      j['usada'] as bool? ?? false,
    );
  }

  /// POST a la misma URL preasignada: consume la invitación.
  Future<Sesion> unirse(Uri url, String dispositivo) async {
    final j = await _pedir('POST', '', url: url, cuerpo: {'dispositivo': dispositivo});
    return _sesion(j);
  }

  // ── Conexión y roles ───────────────────────────────────────

  EstadoMesa _estado(Map<String, dynamic> j, Participante? yo) => EstadoMesa(
        yo ?? Participante.desdeJson(j['yo'] as Map<String, dynamic>),
        j['rol_efectivo'] as String? ?? kRolUsuario,
        (j['participantes'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Participante.desdeJson)
            .toList(),
      );

  Future<EstadoMesa> latido() async => _estado(await _pedir('POST', '/soporte/latido') as Map<String, dynamic>, null);

  /// Sólo admin y agente; para un usuario el backend responde 403.
  Future<({EstadoMesa estado, DateTime? reportes, int ultimoMensaje})> monitor(Participante yo) async {
    final j = await _pedir('GET', '/soporte/monitor') as Map<String, dynamic>;
    return (
      estado: _estado(j, yo),
      reportes: DateTime.tryParse(j['reportes_actualizado'] as String? ?? ''),
      ultimoMensaje: (j['ultimo_mensaje_id'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> salir() => _pedir('POST', '/soporte/salir');

  Future<String> invitar(String rol, String nombre) async {
    final j = await _pedir('POST', '/soporte/invitaciones', cuerpo: {'rol': rol, 'nombre': nombre}) as Map<String, dynamic>;
    return j['url'] as String;
  }

  Future<void> expulsar(String id) => _pedir('DELETE', '/soporte/participantes/$id');

  // ── Reportes ───────────────────────────────────────────────

  Future<List<Reporte>> reportes({String? estado, String? texto}) async {
    final q = <String, String>{
      if (estado != null && estado.isNotEmpty) 'estado': estado,
      if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
    };
    final uri = Uri.parse('$_base/soporte/reportes').replace(queryParameters: q.isEmpty ? null : q);
    final j = await _pedir('GET', '', url: uri) as List;
    return j.whereType<Map<String, dynamic>>().map(Reporte.desdeJson).toList();
  }

  Future<Reporte> reporte(String id) async =>
      Reporte.desdeJson(await _pedir('GET', '/soporte/reportes/${Uri.encodeComponent(id.trim())}') as Map<String, dynamic>);

  Future<Reporte> crearReporte(Map<String, dynamic> datos) async =>
      Reporte.desdeJson(await _pedir('POST', '/soporte/reportes', cuerpo: datos) as Map<String, dynamic>);

  Future<Reporte> actualizarReporte(String id, Map<String, dynamic> cambios) async =>
      Reporte.desdeJson(await _pedir('PATCH', '/soporte/reportes/$id', cuerpo: cambios) as Map<String, dynamic>);

  Future<void> eliminarReporte(String id) => _pedir('DELETE', '/soporte/reportes/$id');

  Future<Reporte> asignar(String id, String agenteId) async => Reporte.desdeJson(
      await _pedir('POST', '/soporte/reportes/$id/asignar', cuerpo: {'agente_id': agenteId}) as Map<String, dynamic>);

  Future<int> asumirDesconectados() async {
    final j = await _pedir('POST', '/soporte/reportes/asumir-desconectados') as Map<String, dynamic>;
    return (j['reasignados'] as num?)?.toInt() ?? 0;
  }

  // ── Mensajes y archivos ────────────────────────────────────

  Future<({List<MensajeSoporte> mensajes, List<ConteoEmisor> conteo})> mensajes({int desde = 0}) async {
    final j = await _pedir('GET', '/soporte/mensajes?desde=$desde') as Map<String, dynamic>;
    return (
      mensajes: (j['mensajes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MensajeSoporte.desdeJson)
          .toList(),
      conteo: (j['conteo'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((c) => ConteoEmisor(
                c['emisor_id'] as String? ?? '',
                c['emisor_nombre'] as String? ?? '',
                (c['total'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
    );
  }

  Future<MensajeSoporte> enviar(Map<String, dynamic> datos) async =>
      MensajeSoporte.desdeJson(await _pedir('POST', '/soporte/mensajes', cuerpo: datos) as Map<String, dynamic>);

  Future<void> limpiarMensajes() => _pedir('DELETE', '/soporte/mensajes');

  /// Sube un archivo con URL preasignada de Supabase Storage y devuelve la
  /// ruta y el nombre seguro para adjuntarlo a un mensaje.
  Future<({String path, String nombre})> subirArchivo(String nombre, Uint8List bytes) async {
    final j = await _pedir('POST', '/soporte/archivos/subida', cuerpo: {'nombre': nombre, 'tamano': bytes.length})
        as Map<String, dynamic>;
    final url = Uri.parse(j['upload_url'] as String);
    try {
      final r = await _c
          .put(url, headers: {'Content-Type': j['content_type'] as String, 'x-upsert': 'false'}, body: bytes)
          .timeout(const Duration(seconds: 40));
      if (r.statusCode >= 300) {
        throw const SoporteException('No fue posible subir el archivo.');
      }
    } on SocketException {
      throw const SoporteException('Sin conexión: no se subió el archivo.', sinConexion: true);
    } on TimeoutException {
      throw const SoporteException('La subida tardó demasiado.', sinConexion: true);
    }
    return (path: j['path'] as String, nombre: j['nombre'] as String);
  }

  Future<String> urlDescarga(String path) async {
    final j = await _pedir('POST', '/soporte/archivos/descarga', cuerpo: {'path': path}) as Map<String, dynamic>;
    return j['url'] as String;
  }
}

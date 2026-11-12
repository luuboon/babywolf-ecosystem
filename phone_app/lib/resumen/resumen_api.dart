// Práctica 3 (ConsultaWeb) — Resumen del blog que se ve arriba del feed.
//
// La app no lee el resumen de una URL fija: el backend entrega una URL
// preasignada (firmada con HMAC) que vale 5 minutos, y la app consulta esa.
// Si alguien la copia y le cambia un carácter, el servidor la rechaza (403);
// si ya venció, responde 410 y la app pide otra sola.
//
// Los tres pasos que pide la práctica:
//   1. URL preasignada   → GET /api/consulta/url devuelve una URL firmada
//                          (HMAC) que vale 5 minutos.
//   2. Solicitud HTTP    → GET a esa URL.
//   3. Procesamiento     → el JSON se convierte en [ResumenSitio].

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/blog_api.dart';

class UrlPreasignada {
  const UrlPreasignada(this.url, this.expira);
  final String url;
  final DateTime? expira;
}

class ResumenSitio {
  const ResumenSitio({
    required this.sitio,
    required this.descripcion,
    required this.totalNoticias,
    required this.porCategoria,
    required this.ultimas,
    required this.generado,
    required this.crudo,
  });

  final String sitio;
  final String descripcion;
  final int totalNoticias;
  final Map<String, int> porCategoria;
  final List<String> ultimas;
  final DateTime? generado;
  final String crudo;

  /// Paso 3: procesar la respuesta. Tolera campos ausentes para no romperse
  /// si el backend agrega o quita algo.
  factory ResumenSitio.desdeJson(Map<String, dynamic> j, String crudo) {
    final cats = <String, int>{};
    final pc = j['por_categoria'];
    if (pc is Map) {
      pc.forEach((k, v) => cats['$k'] = v is int ? v : int.tryParse('$v') ?? 0);
    }
    final ult = <String>[];
    final u = j['ultimas'];
    if (u is List) {
      for (final e in u) {
        if (e is Map) ult.add('${e['titulo'] ?? 'Sin título'} · ${e['categoria'] ?? ''}');
      }
    }
    return ResumenSitio(
      sitio: j['sitio'] as String? ?? 'Sitio',
      descripcion: j['descripcion'] as String? ?? '',
      totalNoticias: j['total_noticias'] is int ? j['total_noticias'] as int : 0,
      porCategoria: cats,
      ultimas: ult,
      generado: DateTime.tryParse(j['generado'] as String? ?? ''),
      crudo: crudo,
    );
  }
}

enum FalloConsulta { sinConexion, urlRechazada, urlExpirada, servidor, formato }

class ConsultaException implements Exception {
  const ConsultaException(this.tipo, this.detalle);
  final FalloConsulta tipo;
  final String detalle;

  @override
  String toString() => detalle;
}

class ConsultaApi {
  ConsultaApi({http.Client? cliente, String? base})
      : _c = cliente ?? http.Client(),
        _base = base ?? BlogApi.base;

  final http.Client _c;
  final String _base;
  static const _timeout = Duration(seconds: 15);

  Future<http.Response> _get(String url) async {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      throw const ConsultaException(FalloConsulta.urlRechazada, 'La URL no tiene un formato válido.');
    }
    try {
      return await _c.get(uri).timeout(_timeout);
    } on SocketException {
      throw const ConsultaException(FalloConsulta.sinConexion, 'Sin conexión a internet.');
    } on TimeoutException {
      throw const ConsultaException(FalloConsulta.sinConexion, 'El servidor no respondió a tiempo.');
    } on http.ClientException {
      throw const ConsultaException(FalloConsulta.sinConexion, 'No se pudo establecer la conexión.');
    } on ArgumentError {
      throw const ConsultaException(FalloConsulta.urlRechazada, 'La URL no tiene un formato válido.');
    }
  }

  /// Decodifica el cuerpo como JSON. Un 200 con bytes inválidos o JSON roto
  /// (proxy que responde HTML, corte a mitad de la respuesta) se convierte en
  /// un fallo de formato controlado en vez de una FormatException suelta.
  Object? _json(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw const ConsultaException(FalloConsulta.formato, 'Respuesta inesperada del servidor.');
    }
  }

  String _mensaje(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return 'El servidor respondió ${r.statusCode}.';
  }

  /// Paso 1: pedir la URL preasignada.
  Future<UrlPreasignada> obtenerUrl() async {
    final r = await _get('$_base/consulta/url');
    if (r.statusCode != 200) {
      throw ConsultaException(FalloConsulta.servidor, _mensaje(r));
    }
    final j = _json(r);
    if (j is! Map || j['url'] is! String) {
      throw const ConsultaException(FalloConsulta.formato, 'Respuesta inesperada del servidor.');
    }
    return UrlPreasignada(j['url'] as String, DateTime.tryParse(j['expira'] as String? ?? ''));
  }

  /// Pasos 2 y 3: petición HTTP a la URL preasignada y procesamiento.
  Future<ResumenSitio> consultar(String url) async {
    final r = await _get(url);
    switch (r.statusCode) {
      case 200:
        break;
      case 403:
        throw ConsultaException(FalloConsulta.urlRechazada, '403 · ${_mensaje(r)}');
      case 410:
        throw ConsultaException(FalloConsulta.urlExpirada, '410 · ${_mensaje(r)}');
      default:
        throw ConsultaException(FalloConsulta.servidor, '${r.statusCode} · ${_mensaje(r)}');
    }
    final j = _json(r);
    if (j is! Map<String, dynamic>) {
      throw const ConsultaException(FalloConsulta.formato, 'Respuesta inesperada del servidor.');
    }
    return ResumenSitio.desdeJson(j, const JsonEncoder.withIndent('  ').convert(j));
  }
}

/// Lo que usa el feed: guarda la URL firmada mientras siga vigente y, si el
/// servidor la rechaza por vencida o alterada, pide una nueva UNA vez.
class ResumenServicio {
  ResumenServicio({ConsultaApi? api, DateTime Function()? reloj})
      : _api = api ?? ConsultaApi(),
        _reloj = reloj ?? DateTime.now;

  final ConsultaApi _api;
  final DateTime Function() _reloj;
  UrlPreasignada? _url;

  /// Cuándo vence la URL firmada con la que se obtuvo el último resumen.
  DateTime? get vence => _url?.expira;

  bool _vigente(UrlPreasignada u) {
    final exp = u.expira;
    return exp == null || exp.difference(_reloj()) > const Duration(seconds: 15);
  }

  Future<ResumenSitio> obtener() async {
    var u = _url;
    if (u == null || !_vigente(u)) u = _url = await _api.obtenerUrl();
    try {
      return await _api.consultar(u.url);
    } on ConsultaException catch (e) {
      if (e.tipo != FalloConsulta.urlExpirada && e.tipo != FalloConsulta.urlRechazada) rethrow;
      final nueva = _url = await _api.obtenerUrl();
      return _api.consultar(nueva.url);
    }
  }
}

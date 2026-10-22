// Práctica 6 — MobileConnect: canal de mensajes entre dos instancias.
//
// El canal es una "sala" en el backend del blog (/api/connect/salas/:sala).
// Las dos instancias de la app escriben y leen la misma sala; cada una
// pregunta cada 2 s si hay mensajes nuevos.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/blog_api.dart';

class MensajeConnect {
  const MensajeConnect({
    required this.id,
    required this.emisor,
    required this.dispositivo,
    required this.texto,
    required this.hora,
  });

  final int id;
  final String emisor; // "A" | "B"
  final String dispositivo;
  final String texto;
  final DateTime hora;

  factory MensajeConnect.desdeJson(Map<String, dynamic> j) => MensajeConnect(
        id: (j['id'] as num?)?.toInt() ?? 0,
        emisor: j['emisor'] as String? ?? '?',
        dispositivo: j['dispositivo'] as String? ?? '',
        texto: j['texto'] as String? ?? '',
        hora: DateTime.tryParse(j['hora'] as String? ?? '') ?? DateTime.now(),
      );
}

class LoteConnect {
  const LoteConnect(this.mensajes, this.conteo);
  final List<MensajeConnect> mensajes;
  final Map<String, int> conteo;
}

class ConnectException implements Exception {
  const ConnectException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Reglas que la app aplica antes de enviar (el backend las repite).
class ReglasConnect {
  static const maxTexto = 280;

  static String? validar(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return 'No se pueden enviar mensajes vacíos';
    if (t.length > maxTexto) return 'Máximo $maxTexto caracteres';
    return null;
  }
}

class ConnectApi {
  ConnectApi({http.Client? cliente, String? base})
      : _c = cliente ?? http.Client(),
        _base = base ?? BlogApi.base;

  final http.Client _c;
  final String _base;
  static const _timeout = Duration(seconds: 10);

  Uri _uri(String sala, [Map<String, String>? q]) =>
      Uri.parse('$_base/connect/salas/${Uri.encodeComponent(sala.trim().toUpperCase())}/mensajes')
          .replace(queryParameters: q);

  Never _falla(Object e) {
    if (e is ConnectException) throw e;
    throw const ConnectException('Sin conexión con el canal.');
  }

  String _error(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return 'El canal respondió ${r.statusCode}.';
  }

  Future<LoteConnect> leer(String sala, {int desde = 0}) async {
    try {
      final r = await _c.get(_uri(sala, {'desde': '$desde'})).timeout(_timeout);
      if (r.statusCode != 200) throw ConnectException(_error(r));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final ms = (j['mensajes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MensajeConnect.desdeJson)
          .toList();
      final conteo = <String, int>{'A': 0, 'B': 0};
      final c = j['conteo'];
      if (c is Map) c.forEach((k, v) => conteo['$k'] = (v as num).toInt());
      return LoteConnect(ms, conteo);
    } catch (e) {
      _falla(e);
    }
  }

  Future<MensajeConnect> enviar(String sala, String emisor, String dispositivo, String texto) async {
    final invalido = ReglasConnect.validar(texto);
    if (invalido != null) throw ConnectException(invalido);
    try {
      final r = await _c
          .post(
            _uri(sala),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'emisor': emisor, 'dispositivo': dispositivo.trim(), 'texto': texto.trim()}),
          )
          .timeout(_timeout);
      if (r.statusCode != 201) throw ConnectException(_error(r));
      return MensajeConnect.desdeJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
    } catch (e) {
      _falla(e);
    }
  }

  Future<void> limpiar(String sala) async {
    try {
      final r = await _c.delete(_uri(sala)).timeout(_timeout);
      if (r.statusCode != 204) throw ConnectException(_error(r));
    } catch (e) {
      _falla(e);
    }
  }
}

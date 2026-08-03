// hub.dart — "aire" del ecosistema BabyWolf: GATT emulado + estado compartido.
//
// Los emuladores Android no tienen radio Bluetooth, así que este proceso ocupa
// el lugar del medio físico. El wearable publica el valor de una característica
// (identificada por su UUID) y el hub lo reenvía tal cual a los suscriptores:
// eso es exactamente la semántica NOTIFY de GATT. El hub NO interpreta los
// bytes, igual que no lo haría una radio — viajan en base64 y sólo el emisor y
// el receptor conocen su tipo (ver gatt_codec.dart).
//
// Además guarda la última noticia seleccionada en el teléfono para que la
// Smart TV la lea y se mantenga sincronizada.
//
// Uso:  dart run hub/hub.dart          (escucha en 0.0.0.0:8090)
//   emuladores Android -> 10.0.2.2:8090
//   PWA en el host     -> localhost:8090

import 'dart:convert';
import 'dart:io';

const _port = 8090;

/// Máximo de un cuerpo POST. Evita que un cliente nos haga crecer sin límite.
const _maxBody = 8 * 1024;

/// Sockets suscritos a NOTIFY. El teléfono se suscribe; el wearable publica.
final _subscribers = <WebSocket>[];

/// Última selección publicada por el teléfono; la TV la consulta por polling.
var _state = <String, dynamic>{'slug': null, 'category': null, 'ts': 0};

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
  stdout.writeln('BabyWolf hub escuchando en :$_port');
  stdout.writeln('  WS   /gatt   NOTIFY emulado (wearable -> teléfono)');
  stdout.writeln('  GET  /state  última noticia seleccionada (TV)');
  stdout.writeln('  POST /state  publicar selección (teléfono)');

  await for (final req in server) {
    try {
      await _route(req);
    } catch (e) {
      stderr.writeln('error en ${req.uri.path}: $e');
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {
        // La respuesta ya se cerró (p. ej. un upgrade a WebSocket); nada que hacer.
      }
    }
  }
}

Future<void> _route(HttpRequest req) async {
  // La PWA corre en otro origen (file:// o localhost:PUERTO), así que necesita CORS.
  final res = req.response;
  res.headers.set('Access-Control-Allow-Origin', '*');
  res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.headers.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method == 'OPTIONS') {
    res.statusCode = HttpStatus.noContent;
    return res.close();
  }

  switch (req.uri.path) {
    case '/gatt':
      if (WebSocketTransformer.isUpgradeRequest(req)) return _handleGatt(req);
      res.statusCode = HttpStatus.badRequest;
      return res.close();
    case '/state':
      return _handleState(req);
    case '/health':
      res.write('ok');
      return res.close();
    default:
      res.statusCode = HttpStatus.notFound;
      return res.close();
  }
}

/// Un socket conectado a /gatt puede publicar y recibir NOTIFY.
Future<void> _handleGatt(HttpRequest req) async {
  final socket = await WebSocketTransformer.upgrade(req);
  _subscribers.add(socket);
  stdout.writeln('+ suscriptor GATT (${_subscribers.length} activos)');

  socket.listen(
    (raw) => _notify(socket, raw),
    onDone: () {
      _subscribers.remove(socket);
      stdout.writeln('- suscriptor GATT (${_subscribers.length} activos)');
    },
    onError: (_) => _subscribers.remove(socket),
  );
}

/// Reenvía a los demás suscriptores. Valida la forma del mensaje pero no los
/// bytes: el hub es el medio, no un participante.
void _notify(WebSocket from, dynamic raw) {
  if (raw is! String || raw.length > _maxBody) return;

  final Object? parsed;
  try {
    parsed = jsonDecode(raw);
  } catch (_) {
    return; // Mensaje ilegible: se descarta en silencio, como una trama corrupta.
  }
  if (parsed is! Map || parsed['uuid'] is! String || parsed['bytes'] is! String) {
    return;
  }

  for (final s in _subscribers) {
    if (s == from) continue; // Nadie recibe su propio NOTIFY.
    try {
      s.add(raw);
    } catch (_) {
      // Socket muriendo; onDone lo quitará de la lista.
    }
  }
}

Future<void> _handleState(HttpRequest req) async {
  final res = req.response;
  res.headers.contentType = ContentType.json;

  if (req.method == 'GET') {
    res.write(jsonEncode(_state));
    return res.close();
  }

  if (req.method == 'POST') {
    final body = await utf8.decoder.bind(req).join();
    if (body.length > _maxBody) {
      res.statusCode = HttpStatus.requestEntityTooLarge;
      return res.close();
    }

    final Object? parsed;
    try {
      parsed = jsonDecode(body);
    } catch (_) {
      res.statusCode = HttpStatus.badRequest;
      res.write('{"error":"json inválido"}');
      return res.close();
    }
    if (parsed is! Map || parsed['slug'] is! String) {
      res.statusCode = HttpStatus.badRequest;
      res.write('{"error":"se esperaba {slug, category}"}');
      return res.close();
    }

    _state = {
      'slug': parsed['slug'],
      'category': parsed['category'] is String ? parsed['category'] : null,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    stdout.writeln('estado -> ${_state['slug']}');
    res.write(jsonEncode(_state));
    return res.close();
  }

  res.statusCode = HttpStatus.methodNotAllowed;
  return res.close();
}

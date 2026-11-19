// Práctica 13/14 · Fase 3 — Pruebas de integración (AUT-04 y AUT-05).
//
// AUT-04: BlogApi habla HTTP de verdad con un servidor local (HttpServer en
// 127.0.0.1, puerto libre): se prueba la pila completa cliente HTTP → API →
// modelo Post, sin depender de internet ni tocar producción.
// AUT-05: ComentariosApi contra un servidor PostgREST simulado en memoria
// (MockClient), porque la URL de Supabase es fija y no se escribe en producción.
//
// Riesgos previos que previenen: D-06 (JSON roto con 200), P12-D01 (escritura
// que siempre devuelve 500), RES-07 (reintento que duplica un comentario).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/comentarios/comentarios_api.dart';
import 'package:phone_app/core/reintento.dart';
import 'package:phone_app/core/supabase.dart';
import 'package:phone_app/services/blog_api.dart';

Future<void> _sinEspera(Duration _) async {}

/// Servidor HTTP local cuyo comportamiento se cambia en cada prueba.
class _ServidorLocal {
  late final HttpServer _s;
  int peticiones = 0;
  Future<void> Function(HttpRequest) comportamiento = (r) async {};

  Future<void> iniciar() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((r) async {
      peticiones++;
      await comportamiento(r);
      await r.response.close();
    });
  }

  String get base => 'http://127.0.0.1:${_s.port}/api';
  Future<void> cerrar() => _s.close(force: true);
}

void main() {
  group('AUT-04 · BlogApi ↔ servidor HTTP real', () {
    final srv = _ServidorLocal();
    setUpAll(() async {
      HttpOverrides.global = null; // sin el cliente simulado de las pruebas de widgets
      await srv.iniciar();
    });
    tearDownAll(srv.cerrar);
    setUp(() => srv.peticiones = 0);

    BlogApi api() => BlogApi(base: srv.base, esperar: _sinEspera);

    test('AUT-04a la API devuelve 200 con la lista y la app la convierte en Post', () async {
      srv.comportamiento = (r) async {
        expect(r.method, 'GET');
        expect(r.uri.path, '/api/posts');
        r.response
          ..statusCode = 200
          ..headers.contentType = ContentType('application', 'json', charset: 'utf-8')
          ..write(jsonEncode([
            {'id': '1', 'title': 'Reseña de Árbol ñandú', 'slug': 'resena', 'category': 'retro', 'created_at': '2026-11-01T10:00:00Z'},
            {'id': '2', 'title': 'Segunda', 'slug': 'segunda'},
          ]));
      };
      final posts = await api().posts();
      expect(posts.map((p) => p.slug), ['resena', 'segunda']);
      expect(posts.first.title, 'Reseña de Árbol ñandú', reason: 'UTF-8 intacto de punta a punta');
      expect(srv.peticiones, 1);
    });

    test('AUT-04b una lista vacía es una respuesta válida (no un error)', () async {
      srv.comportamiento = (r) async => r.response
        ..statusCode = 200
        ..write('[]');
      expect(await api().posts(), isEmpty);
    });

    test('AUT-04c un 200 con JSON roto produce un mensaje controlado y no una FormatException (regresión de D-06)', () async {
      srv.comportamiento = (r) async => r.response
        ..statusCode = 200
        ..write('{"esto no es json');
      await expectLater(
        api().posts(),
        throwsA(isA<BlogApiException>().having((e) => e.mensaje, 'mensaje', 'Respuesta inesperada de la API.')),
      );
    });

    test('AUT-04d un 500 persistente se reintenta 3 veces y se informa el código al usuario', () async {
      srv.comportamiento = (r) async => r.response
        ..statusCode = 500
        ..write('{"error":"interno"}');
      await expectLater(
        api().posts(),
        throwsA(isA<BlogApiException>().having((e) => e.mensaje, 'mensaje', 'El servidor respondió 500.')),
      );
      expect(srv.peticiones, 3, reason: 'política por omisión: 3 intentos');
    });

    test('AUT-04e un 500 pasajero se recupera solo: el segundo intento devuelve la lista', () async {
      srv.comportamiento = (r) async {
        if (srv.peticiones == 1) {
          r.response.statusCode = 503;
        } else {
          r.response
            ..statusCode = 200
            ..write(jsonEncode([{'id': '1', 'title': 'Uno', 'slug': 'uno'}]));
        }
      };
      final posts = await api().posts();
      expect(posts.length, 1);
      expect(srv.peticiones, 2);
    });

    test('AUT-04f un 404 no se reintenta (un solo intento) y se informa', () async {
      srv.comportamiento = (r) async => r.response.statusCode = 404;
      await expectLater(api().posts(), throwsA(isA<BlogApiException>().having((e) => e.mensaje, 'mensaje', contains('404'))));
      expect(srv.peticiones, 1);
    });

    test('AUT-04g servidor apagado: mensaje amable sin la dirección interna', () async {
      final apagado = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final puerto = apagado.port;
      await apagado.close(force: true); // el puerto queda libre y nadie escucha
      final sinServidor = BlogApi(base: 'http://127.0.0.1:$puerto/api', esperar: _sinEspera);
      await expectLater(
        sinServidor.posts(),
        throwsA(isA<BlogApiException>()
            .having((e) => e.mensaje, 'mensaje', isNotEmpty)
            .having((e) => e.mensaje, 'sin datos internos', isNot(contains('127.0.0.1')))),
      );
    });
  });

  group('AUT-05 · ComentariosApi ↔ servidor PostgREST simulado', () {
    test('AUT-05a publicar manda el token y el id generado por la app, y devuelve el comentario creado', () async {
      http.Request? recibida;
      final api = ComentariosApi(cliente: MockClient((r) async {
        recibida = r;
        final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode([
            {'id': cuerpo['id'], 'author_id': 'u1', 'content': cuerpo['content'], 'created_at': '2026-11-18T12:00:00Z'}
          ]),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));
      final c = await api.publicar('token-de-prueba', 'post-1', '  Hola  ', esperar: _sinEspera);
      expect(c.texto, 'Hola', reason: 'el texto se recorta antes de enviarse');
      expect(recibida!.method, 'POST');
      expect(recibida!.headers['Authorization'], 'Bearer token-de-prueba');
      final enviado = jsonDecode(recibida!.body) as Map<String, dynamic>;
      expect(enviado.containsKey('author_id'), isFalse, reason: 'el autor lo toma la base del token, nunca del cliente');
      expect(enviado['post_id'], 'post-1');
      expect(enviado['id'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('AUT-05b la respuesta se pierde pero el servidor sí guardó: el reintento no duplica (1 fila, 2 POST)', () async {
      final filas = <String, Map<String, dynamic>>{};
      var posts = 0;
      final api = ComentariosApi(cliente: MockClient((r) async {
        final cabecera = {'content-type': 'application/json; charset=utf-8'};
        if (r.method == 'POST') {
          posts++;
          final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          final id = cuerpo['id'] as String;
          if (filas.containsKey(id)) {
            return http.Response(jsonEncode({'code': '23505', 'message': 'duplicate key'}), 409, headers: cabecera);
          }
          filas[id] = {'id': id, 'author_id': 'u1', 'content': cuerpo['content'], 'created_at': '2026-11-18T12:00:00Z'};
          if (posts == 1) throw const SocketException('Connection reset by peer');
          return http.Response(jsonEncode([filas[id]]), 201, headers: cabecera);
        }
        final id = (r.url.queryParameters['id'] ?? '').replaceFirst('eq.', '');
        return http.Response(jsonEncode(filas[id] == null ? [] : [filas[id]]), 200, headers: cabecera);
      }));
      final c = await api.publicar('tok', 'post-1', 'Hola', esperar: _sinEspera);
      expect(c.texto, 'Hola');
      expect(filas.length, 1);
      expect(posts, 2);
    });

    test('AUT-05c un 401 no se reintenta y el mensaje del servidor llega al usuario', () async {
      var llamadas = 0;
      final api = ComentariosApi(cliente: MockClient((_) async {
        llamadas++;
        return http.Response(jsonEncode({'message': 'JWT expired'}), 401, headers: {'content-type': 'application/json'});
      }));
      await expectLater(
        api.publicar('tok', 'post-1', 'Hola', esperar: _sinEspera),
        throwsA(isA<ComentarioFallo>().having((e) => e.mensaje, 'mensaje', contains('JWT expired'))),
      );
      expect(llamadas, 1);
    });

    test('AUT-05d un comentario vacío se rechaza en la app y no llega a enviarse al servidor', () async {
      var llamadas = 0;
      final api = ComentariosApi(cliente: MockClient((_) async {
        llamadas++;
        return http.Response('[]', 201);
      }));
      await expectLater(api.publicar('tok', 'post-1', '   '), throwsA(isA<ComentarioFallo>()));
      expect(llamadas, 0);
    });

    test('AUT-05e sin conexión: no se confirma falsamente que el comentario se guardó', () async {
      final api = ComentariosApi(cliente: MockClient((_) async => throw const SocketException('sin red')));
      await expectLater(
        api.publicar('tok', 'post-1', 'Hola', esperar: _sinEspera, politica: const PoliticaReintento(intentos: 2)),
        throwsA(isA<SinConexion>().having((e) => e.mensaje, 'mensaje', contains('No se pudo confirmar'))),
      );
    });
  });
}

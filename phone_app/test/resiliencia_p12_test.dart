// Práctica 12 · Fase 5 — Matriz de resiliencia RES-01 … RES-08 y reintento con
// espera progresiva + idempotencia. Todo con servidores simulados (MockClient)
// y reloj falso: no se escribe nada en producción ni se espera de verdad.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phone_app/comentarios/comentarios_api.dart';
import 'package:phone_app/core/reintento.dart';
import 'package:phone_app/core/supabase.dart';
import 'package:phone_app/services/blog_api.dart';

const _base = 'https://api.test/api';
const _sinJitter = PoliticaReintento(jitter: 0);

http.Response _lista() => http.Response(jsonEncode([{'id': '1', 'title': 'Uno', 'slug': 'uno'}]), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _fila(String id, String texto) => {
      'id': id,
      'author_id': 'u1',
      'content': texto,
      'created_at': '2026-11-11T12:00:00Z',
      'users': {'username': 'Abraham'},
    };

void main() {
  group('PoliticaReintento (espera progresiva)', () {
    test('la espera se duplica: 500, 1000, 2000, 4000 ms y se detiene en el tope de 8 s', () {
      final esperas = [for (var n = 1; n <= 7; n++) _sinJitter.espera(n).inMilliseconds];
      expect(esperas, [500, 1000, 2000, 4000, 8000, 8000, 8000]);
    });

    test('el jitter varía la espera dentro de ±25 %', () {
      const p = PoliticaReintento();
      final r = Random(7);
      for (var i = 0; i < 500; i++) {
        final ms = p.espera(2, r).inMilliseconds; // base 1000 ms
        expect(ms, inInclusiveRange(750, 1250));
      }
      // Con un azar que devuelve 0 y 1 se tocan los dos extremos.
      expect(p.espera(2, _Fijo(0)).inMilliseconds, 750);
      expect(p.espera(2, _Fijo(0.999999)).inMilliseconds, closeTo(1250, 1));
    });
  });

  group('conReintento', () {
    test('éxito a la primera: un solo intento y ninguna espera', () async {
      final esperas = <Duration>[];
      final v = await conReintento((n) async => 'ok$n', esperar: (d) async => esperas.add(d));
      expect(v, 'ok1');
      expect(esperas, isEmpty);
    });

    test('un error que no es transitorio no se reintenta', () async {
      var llamadas = 0;
      await expectLater(
        conReintento((_) async {
          llamadas++;
          throw ArgumentError('mal');
        }, esperar: (_) async {}),
        throwsArgumentError,
      );
      expect(llamadas, 1);
    });

    test('agota los intentos y relanza el último error', () async {
      var llamadas = 0;
      final esperas = <Duration>[];
      await expectLater(
        conReintento((n) async {
          llamadas++;
          throw SocketException('intento $n');
        }, politica: _sinJitter, esperar: (d) async => esperas.add(d)),
        throwsA(isA<SocketException>().having((e) => e.message, 'mensaje', 'intento 3')),
      );
      expect(llamadas, 3);
      expect(esperas, const [Duration(milliseconds: 500), Duration(seconds: 1)]);
    });

    test('el presupuesto de tiempo corta los reintentos', () async {
      var t = DateTime(2026, 11, 11);
      var llamadas = 0;
      await expectLater(
        conReintento((_) async {
          llamadas++;
          t = t.add(const Duration(seconds: 9)); // cada intento tarda 9 s
          throw TimeoutException('x');
        },
            politica: const PoliticaReintento(jitter: 0, intentos: 5, presupuesto: Duration(seconds: 15)),
            reloj: () => t,
            esperar: (_) async {}),
        throwsA(isA<TimeoutException>()),
      );
      expect(llamadas, 2, reason: '9 s + 0.5 s + 9 s = 18.5 s > 15 s: el segundo fallo ya no se reintenta');
    });

    test('intentos = 1 equivale a no reintentar', () async {
      var llamadas = 0;
      await expectLater(
        conReintento((_) async {
          llamadas++;
          throw const SocketException('x');
        }, politica: PoliticaReintento.sinReintento, esperar: (_) async {}),
        throwsA(isA<SocketException>()),
      );
      expect(llamadas, 1);
    });

    test('alReintentar informa intento, error y espera', () async {
      final avisos = <String>[];
      await conReintento((n) async {
        if (n < 3) throw const SocketException('x');
        return 1;
      },
          politica: _sinJitter,
          esperar: (_) async {},
          alReintentar: (n, e, d) => avisos.add('$n:${d.inMilliseconds}'));
      expect(avisos, ['1:500', '2:1000']);
    });
  });

  group('uuidV4 (clave de idempotencia)', () {
    test('formato RFC 4122 versión 4 y sin repetidos en 2000 generados', () {
      final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final ids = {for (var i = 0; i < 2000; i++) uuidV4()};
      expect(ids.length, 2000);
      expect(ids.every(re.hasMatch), isTrue);
    });
  });

  group('Matriz RES (BlogApi y ComentariosApi con servidor simulado)', () {
    test('RES-01 · pérdida de internet durante una consulta: error controlado tras 3 intentos', () async {
      var llamadas = 0;
      final esperas = <Duration>[];
      final api = BlogApi(
        cliente: MockClient((_) async {
          llamadas++;
          throw const SocketException('Failed host lookup');
        }),
        base: _base,
        politica: _sinJitter,
        esperar: (d) async => esperas.add(d),
      );
      await expectLater(api.posts(), throwsA(isA<BlogApiException>().having((e) => e.mensaje, 'mensaje', 'Sin conexión a internet.')));
      expect(llamadas, 3);
      expect(esperas, const [Duration(milliseconds: 500), Duration(seconds: 1)]);
    });

    test('RES-02 · pérdida de internet durante una escritura: no se confirma falsamente', () async {
      final api = ComentariosApi(cliente: MockClient((_) async => throw const SocketException('sin red')));
      await expectLater(
        api.publicar('tok', 'p1', 'Hola', esperar: (_) async {}),
        throwsA(isA<SinConexion>().having((e) => e.mensaje, 'mensaje', contains('No se pudo confirmar'))),
      );
    });

    test('RES-03 · servidor sin respuesta: tiempo agotado controlado en 19.5 s (3 × 6 s + esperas)', () {
      fakeAsync((async) {
        var llamadas = 0;
        final api = BlogApi(
          cliente: MockClient((_) {
            llamadas++;
            return Completer<http.Response>().future; // nunca responde
          }),
          base: _base,
          politica: _sinJitter,
        );
        Object? error;
        var terminado = false;
        api.posts().then<void>((_) {
          terminado = true;
        }, onError: (Object e) {
          error = e;
          terminado = true;
        });
        async.elapse(const Duration(milliseconds: 19400));
        expect(terminado, isFalse, reason: 'aún no vencen los 3 intentos');
        async.elapse(const Duration(milliseconds: 200));
        expect(terminado, isTrue);
        expect(llamadas, 3);
        expect(error, isA<BlogApiException>().having((e) => e.mensaje, 'mensaje', 'El servidor no respondió a tiempo.'));
      });
    });

    test('RES-04 · HTTP 500 persistente: se muestra el error y la app sigue estable (3 intentos)', () async {
      var llamadas = 0;
      final api = BlogApi(
        cliente: MockClient((_) async {
          llamadas++;
          return http.Response('{"error":"boom"}', 500);
        }),
        base: _base,
        esperar: (_) async {},
      );
      await expectLater(api.posts(), throwsA(isA<BlogApiException>().having((e) => e.mensaje, 'mensaje', 'El servidor respondió 500.')));
      expect(llamadas, 3);
    });

    test('RES-04b · un 500 pasajero se recupera solo en el reintento', () async {
      var llamadas = 0;
      final api = BlogApi(
        cliente: MockClient((_) async => ++llamadas == 1 ? http.Response('x', 503) : _lista()),
        base: _base,
        esperar: (_) async {},
      );
      expect((await api.posts()).single.id, '1');
      expect(llamadas, 2);
    });

    test('RES-05 · 401 y 403 no se reintentan y se informan como error de permisos', () async {
      for (final codigo in [401, 403]) {
        var llamadas = 0;
        final api = ComentariosApi(cliente: MockClient((_) async {
          llamadas++;
          return http.Response(jsonEncode({'message': 'permiso denegado'}), codigo);
        }));
        await expectLater(
          api.publicar('tok', 'p1', 'Hola', esperar: (_) async {}),
          throwsA(isA<ComentarioFallo>().having((e) => e.mensaje, 'mensaje', contains('permiso denegado'))),
        );
        expect(llamadas, 1, reason: 'un $codigo no es pasajero: reintentar sólo repetiría la negativa');
      }
    });

    test('RES-06 · recuperación de la conexión: falla dos veces y el tercer intento funciona', () async {
      var llamadas = 0;
      final esperas = <Duration>[];
      final api = BlogApi(
        cliente: MockClient((_) async {
          if (++llamadas < 3) throw const SocketException('sin red');
          return _lista();
        }),
        base: _base,
        politica: _sinJitter,
        esperar: (d) async => esperas.add(d),
      );
      expect((await api.posts()).single.title, 'Uno');
      expect(llamadas, 3);
      expect(esperas.fold<int>(0, (a, d) => a + d.inMilliseconds), 1500);
    });

    test('RES-07 · reintento de una escritura NO duplica: la respuesta se pierde, el servidor sí guardó', () async {
      final servidor = _ServidorComentarios(perderRespuestaDelPrimerPost: true);
      final api = ComentariosApi(cliente: MockClient(servidor.manejar));
      final c = await api.publicar('tok', 'p1', 'Hola', esperar: (_) async {});
      expect(c.texto, 'Hola');
      expect(servidor.filas.length, 1, reason: 'una sola fila aunque hubo dos POST');
      expect(servidor.posts, 2);
      expect(servidor.idsRecibidos.toSet().length, 1, reason: 'los dos POST llevaron el mismo id');
    });

    test('RES-07 (contraste) · sin clave de idempotencia el mismo reintento SÍ duplica', () async {
      // Servidor que genera el id si el cliente no lo manda (como antes de la Práctica 12).
      final servidor = _ServidorComentarios(perderRespuestaDelPrimerPost: true);
      Future<void> enviarAntiguo() async {
        for (var intento = 1; intento <= 2; intento++) {
          try {
            await MockClient(servidor.manejar).post(Uri.parse('https://x/rest/v1/comments'),
                body: jsonEncode({'post_id': 'p1', 'content': 'Hola'})); // sin id
            return;
          } on SocketException {
            continue; // reintento ingenuo
          }
        }
      }

      await enviarAntiguo();
      expect(servidor.filas.length, 2, reason: 'la respuesta perdida + reintento sin id = comentario duplicado');
    });

    test('RES-08 · respuesta tardía: la del primer intento se descarta y la UI no recibe dos resultados', () {
      fakeAsync((async) {
        var llamadas = 0;
        final api = BlogApi(
          cliente: MockClient((_) {
            llamadas++;
            if (llamadas == 1) {
              return Future<http.Response>.delayed(const Duration(seconds: 7), () => http.Response(jsonEncode([{'id': 'TARDIA'}]), 200));
            }
            return Future<http.Response>.value(_lista());
          }),
          base: _base,
          politica: _sinJitter,
        );
        final resultados = <String>[];
        api.posts().then((l) => resultados.add(l.single.id));
        async.elapse(const Duration(seconds: 30)); // incluye el momento en que llega la respuesta tardía
        expect(resultados, ['1'], reason: 'un solo resultado: el del reintento; la tardía (id TARDIA) se ignora');
        expect(llamadas, 2);
      });
    });

    test('RES-08b · dos envíos simultáneos del mismo comentario (doble toque) no crean dos filas', () async {
      final servidor = _ServidorComentarios();
      final api = ComentariosApi(cliente: MockClient(servidor.manejar));
      final id = uuidV4();
      final r = await Future.wait([
        api.publicar('tok', 'p1', 'Hola', idSolicitud: id, esperar: (_) async {}),
        api.publicar('tok', 'p1', 'Hola', idSolicitud: id, esperar: (_) async {}),
      ]);
      expect(r.map((c) => c.id).toSet().length, 1);
      expect(servidor.filas.length, 1);
    });
  });
}

class _Fijo implements Random {
  _Fijo(this.v);
  final double v;
  @override
  bool nextBool() => v > 0.5;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => (v * max).floor();
}

/// Simula PostgREST: guarda filas por id, responde 409/23505 si el id ya existe
/// y, opcionalmente, "pierde" la respuesta del primer POST después de guardar.
class _ServidorComentarios {
  _ServidorComentarios({this.perderRespuestaDelPrimerPost = false});
  final bool perderRespuestaDelPrimerPost;
  final Map<String, Map<String, dynamic>> filas = {};
  final List<String?> idsRecibidos = [];
  int posts = 0;
  int _serie = 0;

  Future<http.Response> manejar(http.Request r) async {
    final cabecera = {'content-type': 'application/json; charset=utf-8'};
    if (r.method == 'POST') {
      posts++;
      final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
      final id = (cuerpo['id'] as String?) ?? 'srv-${++_serie}';
      idsRecibidos.add(cuerpo['id'] as String?);
      if (filas.containsKey(id)) {
        return http.Response(jsonEncode({'code': '23505', 'message': 'duplicate key value violates unique constraint "comments_pkey"'}), 409, headers: cabecera);
      }
      filas[id] = _fila(id, cuerpo['content'] as String);
      if (perderRespuestaDelPrimerPost && posts == 1) {
        throw const SocketException('Connection reset by peer'); // el servidor guardó, el cliente no se enteró
      }
      return http.Response(jsonEncode([filas[id]]), 201, headers: cabecera);
    }
    if (r.method == 'GET') {
      final id = (r.url.queryParameters['id'] ?? '').replaceFirst('eq.', '');
      return http.Response(jsonEncode(filas[id] == null ? [] : [filas[id]]), 200, headers: cabecera);
    }
    return http.Response('[]', 200, headers: cabecera);
  }
}

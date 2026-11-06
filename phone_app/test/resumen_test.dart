// Práctica 3: resumen del blog por URL preasignada, con un servidor simulado.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/resumen/resumen_api.dart';
import 'package:phone_app/resumen/resumen_tarjeta.dart';

const _base = 'https://api.test/api';
const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Object cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: _json);

/// Servidor: entrega URLs firmadas con sig=s1, s2…; sólo acepta la última.
class _Servidor {
  int firmadas = 0;
  bool vencerLaActual = false;

  Future<http.Response> responder(http.Request r) async {
    if (r.url.path.endsWith('/consulta/url')) {
      firmadas++;
      return _ok({
        'url': '$_base/consulta/recurso?exp=9&recurso=resumen&sig=s$firmadas',
        'expira': DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String(),
      });
    }
    final sig = r.url.queryParameters['sig'];
    if (sig == 's$firmadas' && vencerLaActual) {
      vencerLaActual = false;
      return http.Response(jsonEncode({'error': 'La URL expiró.'}), 410, headers: _json);
    }
    if (sig == 's$firmadas') {
      return _ok({
        'sitio': 'BabyWolf Blog',
        'descripcion': 'Noticias de videojuegos retro y consolas',
        'total_noticias': 3,
        'por_categoria': {'retro': 2, 'tech': 1},
        'ultimas': [
          {'titulo': 'Analogue 3D', 'categoria': 'retro'},
        ],
      });
    }
    return http.Response(jsonEncode({'error': 'La URL no es válida o fue modificada.'}), 403, headers: _json);
  }
}

void main() {
  group('ConsultaApi (pasos de la práctica)', () {
    test('Prueba 1 — con conexión: URL preasignada, petición y procesamiento', () async {
      final s = _Servidor();
      final api = ConsultaApi(cliente: MockClient(s.responder), base: _base);
      final url = await api.obtenerUrl();
      final r = await api.consultar(url.url);
      expect(r.sitio, 'BabyWolf Blog');
      expect(r.totalNoticias, 3);
      expect(r.porCategoria['retro'], 2);
      expect(r.ultimas.single, contains('Analogue 3D'));
    });

    test('Prueba 2 — sin conexión: error de tipo sinConexion', () async {
      final api = ConsultaApi(cliente: MockClient((_) => throw const SocketException('sin red')), base: _base);
      await expectLater(
          api.obtenerUrl(), throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.sinConexion)));
    });

    test('Prueba 3 — URL modificada: el servidor la rechaza (403)', () async {
      final s = _Servidor();
      final api = ConsultaApi(cliente: MockClient(s.responder), base: _base);
      await api.obtenerUrl();
      await expectLater(api.consultar('$_base/consulta/recurso?exp=9&recurso=resumen&sig=alterada'),
          throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.urlRechazada)));
    });
  });

  group('ResumenServicio (lo que usa el feed)', () {
    test('reutiliza la URL firmada mientras sigue vigente', () async {
      final s = _Servidor();
      final serv = ResumenServicio(api: ConsultaApi(cliente: MockClient(s.responder), base: _base));
      await serv.obtener();
      await serv.obtener();
      expect(s.firmadas, 1);
      expect(serv.vence, isNotNull);
    });

    test('si la URL venció (410) pide otra una sola vez y responde', () async {
      final s = _Servidor();
      final serv = ResumenServicio(api: ConsultaApi(cliente: MockClient(s.responder), base: _base));
      await serv.obtener();
      s.vencerLaActual = true;
      final r = await serv.obtener();
      expect(r.totalNoticias, 3);
      expect(s.firmadas, 2);
    });
  });

  group('ResumenTarjeta en el feed', () {
    Widget app(ResumenServicio serv, {ValueChanged<String?>? alElegir}) => MaterialApp(
          home: Scaffold(
            body: ResumenTarjeta(servicio: serv, categoria: null, alElegir: alElegir ?? (_) {}),
          ),
        );

    testWidgets('muestra "consultando", luego el total y los temas como filtros', (tester) async {
      final espera = Completer<void>();
      final s = _Servidor();
      final serv = ResumenServicio(
        api: ConsultaApi(
          cliente: MockClient((r) async {
            await espera.future;
            return s.responder(r);
          }),
          base: _base,
        ),
      );
      String? elegido = 'sin tocar';
      await tester.pumpWidget(app(serv, alElegir: (c) => elegido = c));
      expect(find.text('Consultando el resumen del blog…'), findsOneWidget);

      espera.complete();
      await tester.pumpAndSettle();
      expect(find.text('3 noticias'), findsOneWidget);
      expect(find.text('Todas · 3'), findsOneWidget);
      expect(find.text('retro · 2'), findsOneWidget);

      await tester.tap(find.text('retro · 2'));
      expect(elegido, 'retro');
    });

    testWidgets('sin conexión: mensaje y botón Reintentar', (tester) async {
      final serv = ResumenServicio(
        api: ConsultaApi(cliente: MockClient((_) => throw const SocketException('sin red')), base: _base),
      );
      await tester.pumpWidget(app(serv));
      await tester.pumpAndSettle();
      expect(find.textContaining('No fue posible obtener el resumen.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}

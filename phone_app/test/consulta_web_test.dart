// Práctica 3: ConsultaWeb (RF01–RF06) con un servidor simulado.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/laboratorio/p3_consulta/consulta_api.dart';
import 'package:phone_app/laboratorio/p3_consulta/consulta_web_screen.dart';

const _base = 'https://api.test/api';
const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Object cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: _json);

Future<http.Response> _servidor(http.Request r) async {
  if (r.url.path.endsWith('/consulta/url')) {
    return _ok({'url': '$_base/consulta/recurso?exp=9&recurso=resumen&sig=abc', 'expira': '2026-10-22T23:00:00Z'});
  }
  if (r.url.queryParameters['sig'] == 'abc') {
    return _ok({
      'sitio': 'BabyWolf Blog',
      'descripcion': 'Noticias de videojuegos retro y consolas',
      'total_noticias': 2,
      'por_categoria': {'retro': 2},
      'ultimas': [
        {'titulo': 'Analogue 3D', 'categoria': 'retro'},
      ],
    });
  }
  return http.Response(jsonEncode({'error': 'La URL no es válida o fue modificada.'}), 403, headers: _json);
}

Widget _app(ConsultaApi api) => MaterialApp(home: ConsultaWebScreen(api: api));

void main() {
  test('Prueba 1 — con conexión: URL preasignada, petición y procesamiento', () async {
    final api = ConsultaApi(cliente: MockClient(_servidor), base: _base);
    final url = await api.obtenerUrl();
    final r = await api.consultar(url.url);
    expect(r.sitio, 'BabyWolf Blog');
    expect(r.porCategoria['retro'], 2);
    expect(r.ultimas.single, contains('Analogue 3D'));
  });

  test('Prueba 2 — sin conexión: error de tipo sinConexion', () async {
    final api = ConsultaApi(cliente: MockClient((_) => throw const SocketException('sin red')), base: _base);
    await expectLater(api.obtenerUrl(), throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.sinConexion)));
  });

  test('Prueba 3 — URL modificada: el servidor la rechaza', () async {
    final api = ConsultaApi(cliente: MockClient(_servidor), base: _base);
    await expectLater(api.consultar('$_base/consulta/recurso?exp=9&recurso=otro&sig=xyz'),
        throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.urlRechazada)));
  });

  testWidgets('RF01, RF02, RF05 y RF04 en pantalla', (tester) async {
    final espera = Completer<void>();
    final api = ConsultaApi(
      cliente: MockClient((r) async {
        await espera.future;
        return _servidor(r);
      }),
      base: _base,
    );
    await tester.pumpWidget(_app(api));
    expect(find.text('Consulta de información'), findsOneWidget); // RF01
    expect(find.text('CONSULTAR'), findsOneWidget); // RF02

    await tester.tap(find.text('CONSULTAR'));
    await tester.pump();
    expect(find.text('Consultando...'), findsOneWidget); // RF05

    espera.complete();
    await tester.pumpAndSettle();
    expect(find.text('BabyWolf Blog'), findsOneWidget); // RF04
    expect(find.text('Consultando...'), findsNothing);
  });

  testWidgets('RF06 sin conexión', (tester) async {
    final api = ConsultaApi(cliente: MockClient((_) => throw const SocketException('sin red')), base: _base);
    await tester.pumpWidget(_app(api));
    await tester.tap(find.text('CONSULTAR'));
    await tester.pumpAndSettle();
    expect(find.text('No fue posible obtener la información.'), findsOneWidget);
  });
}

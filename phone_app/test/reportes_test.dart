// Prácticas 9 y 10: reportes en la base compartida, sincronía y conflictos.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/core/supabase.dart';
import 'package:phone_app/models/post.dart';
import 'package:phone_app/reportes/reportes_api.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _fila({int version = 1, String estado = 'abierta', String prioridad = 'media', String desc = ''}) => {
      'id': 'r1',
      'titulo': 'Imagen rota',
      'descripcion': desc,
      'estado': estado,
      'prioridad': prioridad,
      'creado_por': 'uid-a',
      'post_slug': 'zelda',
      'post_titulo': 'Zelda retro',
      'version': version,
      'created_at': '2026-11-06T18:00:00Z',
      'updated_at': '2026-11-06T18:05:00Z',
      'actualizado_por': 'uid-admin',
    };

http.Response _r(Object cuerpo, [int codigo = 200]) => http.Response(jsonEncode(cuerpo), codigo, headers: _json);

void main() {
  final post = Post(
    id: 'p1',
    title: 'Zelda retro',
    slug: 'zelda',
    content: '',
    category: 'retro',
    coverImageUrl: '',
    createdAt: DateTime(2026),
  );

  test('el reporte se interpreta con textos legibles', () {
    final r = Reporte.desdeJson(_fila(version: 3, estado: 'en_proceso', prioridad: 'critica'));
    expect(r.estadoTexto, 'En proceso');
    expect(r.prioridadTexto, 'Crítica');
    expect(r.version, 3);
    expect(r.postTitulo, 'Zelda retro');
  });

  test('DB-02: crear no manda el dueño (lo pone la base) y liga la noticia', () async {
    late Map<String, dynamic> cuerpo;
    final api = ReportesApi(cliente: MockClient((r) async {
      cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
      expect(r.method, 'POST');
      expect(r.headers['Prefer'], 'return=representation');
      return _r([_fila()], 201);
    }));
    final r = await api.crear('tok', titulo: 'Imagen rota', descripcion: ' No carga ', prioridad: 'alta', post: post);
    expect(r.id, 'r1');
    expect(cuerpo.containsKey('creado_por'), isFalse);
    expect(cuerpo['post_slug'], 'zelda');
    expect(cuerpo['descripcion'], 'No carga');
    expect(cuerpo['prioridad'], 'alta');
  });

  test('crear valida antes de enviar', () async {
    var pedidas = 0;
    final api = ReportesApi(cliente: MockClient((_) async {
      pedidas++;
      return _r([]);
    }));
    await expectLater(api.crear('tok', titulo: ' '), throwsA(isA<ReporteFallo>()));
    await expectLater(api.crear('tok', titulo: 'Otro', descripcion: 'a' * 501), throwsA(isA<ReporteFallo>()));
    expect(pedidas, 0);
  });

  test('DB-06: guardar manda sólo lo que cambió y exige la versión abierta', () async {
    late http.Request pedida;
    final api = ReportesApi(cliente: MockClient((r) async {
      pedida = r;
      return _r([_fila(version: 4, prioridad: 'critica')]);
    }));
    final abierto = Reporte.desdeJson(_fila(version: 3));
    final nuevo = await api.guardar('tok', abierto, {'prioridad': 'critica'});
    expect(pedida.method, 'PATCH');
    expect(pedida.url.queryParameters['id'], 'eq.r1');
    expect(pedida.url.queryParameters['version'], 'eq.3');
    expect(jsonDecode(pedida.body), {'prioridad': 'critica'});
    expect(nuevo.version, 4);
  });

  test('sin cambios no se envía nada', () async {
    var pedidas = 0;
    final api = ReportesApi(cliente: MockClient((_) async {
      pedidas++;
      return _r([]);
    }));
    final abierto = Reporte.desdeJson(_fila());
    expect(await api.guardar('tok', abierto, {}), same(abierto));
    expect(pedidas, 0);
  });

  test('DB-07: si otro guardó antes, no se pisa: ConflictoVersion con lo que quedó', () async {
    final api = ReportesApi(cliente: MockClient((r) async {
      if (r.method == 'PATCH') return _r([]); // la versión 3 ya no existe
      return _r([_fila(version: 4, prioridad: 'alta')]);
    }));
    final abierto = Reporte.desdeJson(_fila(version: 3));
    await expectLater(
      api.guardar('tok', abierto, {'estado': 'en_proceso'}),
      throwsA(isA<ConflictoVersion>()
          .having((c) => c.actual.version, 'versión', 4)
          .having((c) => abierto.diferencias(c.actual), 'cambió', ['prioridad'])),
    );
  });

  test('0 filas y el reporte ya no se ve = sin permiso (RLS), no conflicto', () async {
    final api = ReportesApi(cliente: MockClient((_) async => _r([])));
    await expectLater(
      api.guardar('tok', Reporte.desdeJson(_fila()), {'estado': 'cerrada'}),
      throwsA(isA<ReporteFallo>()),
    );
  });

  test('DB-09: sin conexión se lanza SinConexion (nunca un éxito falso)', () async {
    final api = ReportesApi(cliente: MockClient((_) => throw const SocketException('sin red')));
    await expectLater(api.crear('tok', titulo: 'Imagen rota'), throwsA(isA<SinConexion>()));
    await expectLater(api.guardar('tok', Reporte.desdeJson(_fila()), {'prioridad': 'alta'}), throwsA(isA<SinConexion>()));
  });

  test('un rechazo de la base (42501) llega como error, no como éxito', () async {
    final api = ReportesApi(cliente: MockClient((_) async => _r({'code': '42501', 'message': 'permission denied for table incidencias'}, 401)));
    await expectLater(
      api.listar('tok'),
      throwsA(isA<ReporteFallo>().having((e) => e.mensaje, 'mensaje', contains('permission denied'))),
    );
  });
}

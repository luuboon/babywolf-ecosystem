// Práctica 11 — Pruebas de caja blanca (Fase 2) de la app.
//
// Métodos críticos elegidos (ver docs/practicas/practica11_whitebox/):
//   M1  Validar.contrasenaNueva      → validación          (V(G) = 6)
//   M2  buscarPosts / normalizar     → procesamiento       (V(G) = 5 / 3)
//   M3  ConsultaApi.consultar / _get → comunicación        (V(G) = 6 / 6)
//   M4  ResumenServicio.obtener      → comunicación+reintento (V(G) = 6)
//   M5  BlogApi.posts                → comunicación (feed) (V(G) = 7)
//   M6  LimiteIntentos               → estado y tiempo     (V(G) = 6)
//
// Cada prueba nombra el camino (P#) del grafo de flujo que ejecuta. La
// cobertura se mide con: ./docs/practicas/practica11_whitebox/medicion/cobertura.sh
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/core/validacion.dart';
import 'package:phone_app/models/post.dart';
import 'package:phone_app/resumen/resumen_api.dart';
import 'package:phone_app/services/blog_api.dart';
import 'package:phone_app/services/busqueda.dart';

const _base = 'https://api.test/api';
const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Object cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: _json);
http.Response _err(int codigo, [String? mensaje]) =>
    http.Response(mensaje == null ? 'no es json' : jsonEncode({'error': mensaje}), codigo, headers: _json);

Post _post(String id, String titulo, {String texto = '', String cat = 'retro'}) => Post(
      id: id,
      title: titulo,
      slug: 's-$id',
      content: texto,
      category: cat,
      coverImageUrl: '',
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  // ───────────────────────────────────────────────────────────────
  // M1 · Validar.contrasenaNueva
  //   N1 vacía? → N2 <8? → N3 >72? → N4 (sin letra C1 || sin dígito C2)? → fin
  //   Caminos independientes: P1 vacía · P2 corta · P3 larga · P4 C1 · P5 C2 · P6 válida
  // ───────────────────────────────────────────────────────────────
  group('M1 Validar.contrasenaNueva', () {
    test('P1 · vacía y null', () {
      expect(Validar.contrasenaNueva(''), 'Escribe una contraseña');
      expect(Validar.contrasenaNueva(null), 'Escribe una contraseña');
    });

    test('P2 · demasiado corta (límite: 7 falla, 8 pasa)', () {
      expect(Validar.contrasenaNueva('abc1234'), contains('al menos 8'));
      expect(Validar.contrasenaNueva('abc12345'), isNull);
    });

    test('P3 · demasiado larga (límite: 72 pasa, 73 falla)', () {
      final p72 = 'a1${'x' * 70}';
      expect(p72.length, 72);
      expect(Validar.contrasenaNueva(p72), isNull);
      expect(Validar.contrasenaNueva('${p72}x'), contains('Máximo 72'));
    });

    test('P4 · C1 verdadera: sin letras (sólo dígitos)', () {
      expect(Validar.contrasenaNueva('12345678'), 'Combina letras y números');
    });

    test('P5 · C1 falsa y C2 verdadera: sin dígitos (sólo letras)', () {
      expect(Validar.contrasenaNueva('abcdefgh'), 'Combina letras y números');
    });

    test('P6 · C1 falsa y C2 falsa: válida', () {
      expect(Validar.contrasenaNueva('abcd1234'), isNull);
      expect(Validar.contrasenaNueva('1234abcd'), isNull);
    });

    test('Excepciones/bordes: espacios cuentan, Unicode y símbolos no rompen', () {
      expect(Validar.contrasenaNueva('        '), 'Combina letras y números'); // 8 espacios
      expect(Validar.contrasenaNueva('ñandú123'), isNull);
      expect(Validar.contrasenaNueva('😀😀😀😀😀😀😀😀'), 'Combina letras y números');
    });
  });

  group('M1b Validar.correo / apodo (decisiones adicionales)', () {
    test('correo: vacío, largo, formato y válido', () {
      expect(Validar.correo('  '), 'Escribe tu correo');
      expect(Validar.correo('${'a' * 120}@x.com'), contains('Máximo'));
      expect(Validar.correo('sin-arroba'), contains('correo válido'));
      expect(Validar.correo('a@b'), contains('correo válido'));
      expect(Validar.correo('  ana@correo.com '), isNull);
    });

    test('apodo: vacío, 2/3 y 20/21 caracteres, símbolos', () {
      expect(Validar.apodo(''), 'Escribe un nombre de usuario');
      expect(Validar.apodo('ab'), contains('Mínimo 3'));
      expect(Validar.apodo('abc'), isNull);
      expect(Validar.apodo('a' * 20), isNull);
      expect(Validar.apodo('a' * 21), contains('Máximo 20'));
      expect(Validar.apodo('ana lopez'), contains('solo letras'));
    });
  });

  // ───────────────────────────────────────────────────────────────
  // M2 · buscarPosts / normalizar
  // ───────────────────────────────────────────────────────────────
  group('M2 buscarPosts', () {
    final feed = [
      _post('1', 'Zelda en el N64', texto: 'Clásico de Nintendo', cat: 'nintendo'),
      _post('2', 'Emuladores', texto: 'Cómo jugar Zelda en PC', cat: 'guias'),
      _post('3', 'Mega Drive', texto: 'YM2612', cat: 'sega'),
    ];
    List<String> ids(List<Post> l) => l.map((p) => p.id).toList();

    test('P1 · consulta vacía devuelve la misma lista', () {
      expect(identical(buscarPosts(feed, '   '), feed), isTrue);
    });

    test('P2 · lista vacía: el ciclo no itera', () {
      expect(buscarPosts(const [], 'zelda'), isEmpty);
    });

    test('P3 · ninguna palabra coincide: se descarta (continue)', () {
      expect(buscarPosts(feed, 'playstation'), isEmpty);
    });

    test('P4 · todas las palabras en el título: grupo enTitulo', () {
      expect(ids(buscarPosts(feed, 'zelda n64')), ['1']);
    });

    test('P5 · coincide sólo en el texto: grupo enTexto, después del título', () {
      expect(ids(buscarPosts(feed, 'zelda')), ['1', '2']);
    });

    test('Condición compuesta: cada palabra por separado (A y B)', () {
      expect(ids(buscarPosts(feed, 'zelda sega')), isEmpty); // A verdadera, B falsa
      expect(ids(buscarPosts(feed, 'nintendo zelda')), ['1']); // ambas verdaderas
    });

    test('Busca también en la categoría', () {
      expect(ids(buscarPosts(feed, 'guias')), ['2']);
    });
  });

  group('M2b normalizar', () {
    test('rama con acento / sin acento / espacios', () {
      expect(normalizar('ÁÉÍÓÚ ñ ç'), 'aeiou n c');
      expect(normalizar('  a \n\t b '), 'a b');
      expect(normalizar(''), '');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // M3 · ConsultaApi.consultar  (y _get)
  //   _get: URL mal formada · Socket · Timeout · ClientException · ArgumentError · ok
  //   consultar: switch 200 / 403 / 410 / default; luego ¿Map?
  // ───────────────────────────────────────────────────────────────
  group('M3 ConsultaApi.consultar', () {
    ConsultaApi api(Future<http.Response> Function(http.Request) h) => ConsultaApi(cliente: MockClient(h), base: _base);
    Future<ConsultaException> falla(ConsultaApi a, [String url = '$_base/consulta/recurso?sig=1']) async {
      try {
        await a.consultar(url);
      } on ConsultaException catch (e) {
        return e;
      }
      fail('se esperaba ConsultaException');
    }

    test('P1 · 200 con objeto JSON: se procesa', () async {
      final r = await api((_) async => _ok({'sitio': 'BW', 'total_noticias': 2})).consultar('$_base/x');
      expect(r.sitio, 'BW');
      expect(r.totalNoticias, 2);
    });

    test('P2 · 200 pero el JSON es una lista: formato', () async {
      final e = await falla(api((_) async => _ok([1, 2])));
      expect(e.tipo, FalloConsulta.formato);
    });

    test('P2b · 200 con JSON roto: fallo de formato controlado (corrige D-06)', () async {
      // Antes de la corrección jsonDecode lanzaba una FormatException que
      // consultar no capturaba y subía a la pantalla. Ver informe, D-06.
      final e = await falla(api((_) async => http.Response('{roto', 200)));
      expect(e.tipo, FalloConsulta.formato);
      expect(e.detalle, 'Respuesta inesperada del servidor.');
    });

    test('P2c · 200 con bytes que no son UTF-8: también fallo de formato', () async {
      final e = await falla(api((_) async => http.Response.bytes([0xff, 0xfe, 0xfd], 200)));
      expect(e.tipo, FalloConsulta.formato);
    });

    test('P3 · 403: URL rechazada, con el mensaje del servidor', () async {
      final e = await falla(api((_) async => _err(403, 'modificada')));
      expect(e.tipo, FalloConsulta.urlRechazada);
      expect(e.detalle, '403 · modificada');
    });

    test('P4 · 410: URL expirada', () async {
      final e = await falla(api((_) async => _err(410, 'expiró')));
      expect(e.tipo, FalloConsulta.urlExpirada);
    });

    test('P5 · cualquier otro código: servidor; con cuerpo no JSON usa un texto genérico', () async {
      final e = await falla(api((_) async => _err(500)));
      expect(e.tipo, FalloConsulta.servidor);
      expect(e.detalle, '500 · El servidor respondió 500.');
      final e2 = await falla(api((_) async => _err(404, 'no existe')));
      expect(e2.detalle, '404 · no existe');
    });

    test('Excepciones de _get: URL inválida', () async {
      final e = await falla(api((_) async => _ok({})), 'http://[');
      expect(e.tipo, FalloConsulta.urlRechazada);
    });

    test('Excepciones de _get: sin red, tiempo agotado, cliente y argumento', () async {
      final casos = <Object, FalloConsulta>{
        const SocketException('sin red'): FalloConsulta.sinConexion,
        TimeoutException('lento'): FalloConsulta.sinConexion,
        http.ClientException('reset'): FalloConsulta.sinConexion,
        ArgumentError('uri'): FalloConsulta.urlRechazada,
      };
      for (final c in casos.entries) {
        final e = await falla(api((_) async => throw c.key));
        expect(e.tipo, c.value, reason: '${c.key}');
      }
    });

    test('El mensaje de red no revela el servidor ni detalles del sistema', () async {
      final e = await falla(api((_) async => throw const SocketException('Failed host lookup: api.test')));
      expect(e.detalle, isNot(contains('api.test')));
      expect(e.detalle, isNot(contains('SocketException')));
    });

    test('obtenerUrl: 200 válido, código de error y formato inesperado', () async {
      final ok = await api((_) async => _ok({'url': '$_base/r', 'expira': '2026-11-11T12:00:00Z'})).obtenerUrl();
      expect(ok.url, '$_base/r');
      expect(ok.expira, DateTime.utc(2026, 11, 11, 12));
      expect(
        () => api((_) async => _err(503, 'sin clave')).obtenerUrl(),
        throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.servidor)),
      );
      expect(
        () => api((_) async => http.Response('<html>502</html>', 200)).obtenerUrl(),
        throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.formato)),
      );
      expect(
        () => api((_) async => _ok({'otra': 1})).obtenerUrl(),
        throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.formato)),
      );
    });
  });

  group('M3b ResumenSitio.desdeJson (procesamiento tolerante)', () {
    test('campos ausentes, tipos distintos y entradas que no son mapas', () {
      final r = ResumenSitio.desdeJson({
        'por_categoria': {'retro': 2, 'tech': '3', 'raro': 'x'},
        'ultimas': [
          {'titulo': 'A', 'categoria': 'retro'},
          {'categoria': 'tech'},
          'basura',
        ],
        'total_noticias': '9', // no es int → 0
        'generado': 'no es fecha',
      }, 'crudo');
      expect(r.sitio, 'Sitio');
      expect(r.totalNoticias, 0);
      expect(r.porCategoria, {'retro': 2, 'tech': 3, 'raro': 0});
      expect(r.ultimas, ['A · retro', 'Sin título · tech']);
      expect(r.generado, isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // M4 · ResumenServicio.obtener  (reintento controlado de UNA vez)
  // ───────────────────────────────────────────────────────────────
  group('M4 ResumenServicio.obtener', () {
    final ahora = DateTime.utc(2026, 11, 11, 12);

    ({ResumenServicio servicio, List<String> pedidos}) montar({
      required Duration vida,
      required List<int> codigosRecurso,
    }) {
      final pedidos = <String>[];
      var firmadas = 0;
      var i = 0;
      Future<http.Response> h(http.Request r) async {
        pedidos.add(r.url.path);
        if (r.url.path.endsWith('/consulta/url')) {
          firmadas++;
          return _ok({'url': '$_base/consulta/recurso?sig=s$firmadas', 'expira': ahora.add(vida).toIso8601String()});
        }
        final c = codigosRecurso[i < codigosRecurso.length ? i : codigosRecurso.length - 1];
        i++;
        return c == 200 ? _ok({'sitio': 'BW', 'total_noticias': 1}) : _err(c, 'x');
      }

      final api = ConsultaApi(cliente: MockClient(h), base: _base);
      return (servicio: ResumenServicio(api: api, reloj: () => ahora), pedidos: pedidos);
    }

    int urlsPedidas(List<String> p) => p.where((x) => x.endsWith('/consulta/url')).length;

    test('P1 · primera vez: pide la URL y consulta', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [200]);
      expect((await m.servicio.obtener()).sitio, 'BW');
      expect(urlsPedidas(m.pedidos), 1);
    });

    test('P2 · URL vigente: se reutiliza (no pide otra)', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [200]);
      await m.servicio.obtener();
      await m.servicio.obtener();
      expect(urlsPedidas(m.pedidos), 1);
    });

    test('P3 · a punto de vencer (margen de 15 s; límite: 15 s NO es vigente, 16 s sí)', () async {
      final a = montar(vida: const Duration(seconds: 15), codigosRecurso: [200]);
      await a.servicio.obtener();
      await a.servicio.obtener();
      expect(urlsPedidas(a.pedidos), 2, reason: '15 s exactos ya no se consideran vigentes');
      final b = montar(vida: const Duration(seconds: 16), codigosRecurso: [200]);
      await b.servicio.obtener();
      await b.servicio.obtener();
      expect(urlsPedidas(b.pedidos), 1);
    });

    test('P4 · 410 una vez: pide otra URL y reintenta con éxito', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [410, 200]);
      expect((await m.servicio.obtener()).sitio, 'BW');
      expect(urlsPedidas(m.pedidos), 2);
    });

    test('P5 · 403 una vez: también reintenta una vez', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [403, 200]);
      await m.servicio.obtener();
      expect(urlsPedidas(m.pedidos), 2);
    });

    test('P6 · el reintento también falla: no hay bucle, se propaga', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [410, 410]);
      await expectLater(m.servicio.obtener(), throwsA(isA<ConsultaException>()));
      expect(urlsPedidas(m.pedidos), 2, reason: 'exactamente un reintento');
    });

    test('P7 · error del servidor (500): no reintenta', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [500]);
      await expectLater(
        m.servicio.obtener(),
        throwsA(isA<ConsultaException>().having((e) => e.tipo, 'tipo', FalloConsulta.servidor)),
      );
      expect(urlsPedidas(m.pedidos), 1);
    });

    test('P8 · la URL no trae fecha de vencimiento: se considera vigente y se reutiliza (condición E1)', () async {
      var urls = 0;
      final api = ConsultaApi(
        cliente: MockClient((r) async {
          if (r.url.path.endsWith('/consulta/url')) {
            urls++;
            return _ok({'url': '$_base/consulta/recurso?sig=s'});
          }
          return _ok({'sitio': 'BW', 'total_noticias': 1});
        }),
        base: _base,
      );
      final s = ResumenServicio(api: api, reloj: () => ahora);
      await s.obtener();
      await s.obtener();
      expect(urls, 1, reason: 'sin fecha no hay motivo para pedir otra URL');
      expect(s.vence, isNull);
    });

    test('vence expone la fecha de la URL en uso', () async {
      final m = montar(vida: const Duration(minutes: 5), codigosRecurso: [200]);
      expect(m.servicio.vence, isNull);
      await m.servicio.obtener();
      expect(m.servicio.vence, ahora.add(const Duration(minutes: 5)));
    });
  });

  // ───────────────────────────────────────────────────────────────
  // M5 · BlogApi.posts  (lo que alimenta el feed)
  // ───────────────────────────────────────────────────────────────
  group('M5 BlogApi.posts', () {
    BlogApi api(Future<http.Response> Function(http.Request) h) => BlogApi(cliente: MockClient(h), base: _base);
    Future<String> mensaje(BlogApi a) async {
      try {
        await a.posts();
      } on BlogApiException catch (e) {
        return e.mensaje;
      }
      fail('se esperaba BlogApiException');
    }

    test('P1 · 200 con lista: se convierten a Post y se ignoran los que no son objetos', () async {
      final lista = await api((r) async {
        expect(r.url.toString(), '$_base/posts');
        return _ok([
          {'id': '1', 'title': 'Uno', 'slug': 'uno'},
          'basura',
          {'id': '2'},
        ]);
      }).posts();
      expect(lista.map((p) => p.id), ['1', '2']);
      expect(lista[1].title, 'Sin título');
      expect(lista[1].category, 'general');
    });

    test('P2 · lista vacía es válida', () async {
      expect(await api((_) async => _ok([])).posts(), isEmpty);
    });

    test('P3 · código distinto de 200', () async {
      expect(await mensaje(api((_) async => _err(500, 'x'))), 'El servidor respondió 500.');
      expect(await mensaje(api((_) async => _err(404, 'x'))), 'El servidor respondió 404.');
    });

    test('P4 · el cuerpo no es una lista', () async {
      expect(await mensaje(api((_) async => _ok({'a': 1}))), 'Respuesta inesperada de la API.');
    });

    test('P5 · JSON roto y bytes que no son UTF-8', () async {
      expect(await mensaje(api((_) async => http.Response('{roto', 200))), 'Respuesta inesperada de la API.');
      expect(
        await mensaje(api((_) async => http.Response.bytes([0xff, 0xfe, 0xfd], 200))),
        'Respuesta inesperada de la API.',
      );
    });

    test('P6 · fallas de red con mensajes que no revelan el servidor', () async {
      expect(await mensaje(api((_) async => throw const SocketException('Failed host lookup: railway.app'))),
          'Sin conexión a internet.');
      expect(await mensaje(api((_) async => throw TimeoutException('x'))), 'El servidor no respondió a tiempo.');
      expect(await mensaje(api((_) async => throw http.ClientException('reset'))), 'No se pudo establecer la conexión.');
    });

    test('toString de la excepción es el mensaje (lo que ve el usuario en el feed)', () {
      expect('${const BlogApiException('hola')}', 'hola');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // M6 · LimiteIntentos (estado + tiempo, con reloj inyectado)
  // ───────────────────────────────────────────────────────────────
  group('M6 LimiteIntentos', () {
    test('4 fallos no bloquean, el 5.º sí (límite)', () {
      var t = DateTime(2026, 11, 11, 12);
      final l = LimiteIntentos(reloj: () => t);
      for (var i = 0; i < 4; i++) {
        l.fallo();
      }
      expect(l.bloqueoRestante, isNull);
      l.fallo();
      expect(l.bloqueoRestante, const Duration(seconds: 30));
      t = t.add(const Duration(seconds: 10));
      expect(l.bloqueoRestante, const Duration(seconds: 20));
    });

    test('al terminar la espera se desbloquea y se reinicia el contador', () {
      var t = DateTime(2026, 11, 11, 12);
      final l = LimiteIntentos(reloj: () => t);
      for (var i = 0; i < 5; i++) {
        l.fallo();
      }
      t = t.add(const Duration(seconds: 31));
      expect(l.bloqueoRestante, isNull);
      expect(l.fallos, 0);
    });

    test('un acierto reinicia todo', () {
      final l = LimiteIntentos();
      l.fallo();
      l.fallo();
      l.exito();
      expect(l.fallos, 0);
      expect(l.bloqueoRestante, isNull);
    });
  });
}

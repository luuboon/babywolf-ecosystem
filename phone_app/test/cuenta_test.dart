// Prácticas 5 y 10: validación, inicio de sesión con Supabase Auth (simulado),
// bloqueo por intentos, renovación del token y registro sin datos sensibles.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/core/log_seguro.dart';
import 'package:phone_app/core/sesion.dart';
import 'package:phone_app/core/validacion.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// Supabase Auth simulado. Contraseña correcta: Correcta123.
class _Auth {
  final pedidas = <String>[];
  var refrescos = 0;

  Map<String, Object> _tokens(String acc, String ref) => {
        'access_token': acc,
        'refresh_token': ref,
        'expires_in': 3600,
        'user': {
          'id': 'uid-1',
          'email': 'abraham@bw.test',
          'user_metadata': {'username': 'lector'},
        },
      };

  Future<http.Response> responder(http.Request r) async {
    pedidas.add('${r.method} ${r.url.path}');
    final cuerpo = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    final grant = r.url.queryParameters['grant_type'];
    if (r.url.path == '/auth/v1/token' && grant == 'password') {
      if (cuerpo['password'] == 'Correcta123') return http.Response(jsonEncode(_tokens('acc1', 'ref1')), 200, headers: _json);
      return http.Response('{"error":"invalid_grant","error_description":"Invalid login credentials"}', 400, headers: _json);
    }
    if (r.url.path == '/auth/v1/token' && grant == 'refresh_token') {
      refrescos++;
      if (cuerpo['refresh_token'] == 'ref1') return http.Response(jsonEncode(_tokens('acc2', 'ref2')), 200, headers: _json);
      return http.Response('{"error":"invalid_grant"}', 400, headers: _json);
    }
    if (r.url.path == '/rest/v1/users') {
      return http.Response('[{"username":"abraham","role":"admin"}]', 200, headers: _json);
    }
    if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
    if (r.url.path == '/auth/v1/signup') {
      if (cuerpo['email'] == 'confirmar@bw.test') return http.Response('{"id":"uid-2","email":"confirmar@bw.test"}', 200, headers: _json);
      if (cuerpo['email'] == 'repetido@bw.test') return http.Response('{"msg":"Database error saving new user"}', 500, headers: _json);
      return http.Response(jsonEncode(_tokens('acc9', 'ref9')), 200, headers: _json);
    }
    return http.Response('no', 404);
  }
}

void main() {
  setUp(LogSeguro.limpiar);

  group('Validar', () {
    test('correo', () {
      expect(Validar.correo(''), isNotNull);
      expect(Validar.correo('abraham@'), isNotNull);
      expect(Validar.correo("x' OR 1=1 --"), isNotNull);
      expect(Validar.correo('abraham@bw.test'), isNull);
    });

    test('contraseña al entrar: sólo obligatoria y con tope; los espacios cuentan', () {
      expect(Validar.contrasena(''), isNotNull);
      expect(Validar.contrasena('a' * 73), isNotNull);
      expect(Validar.contrasena(' corta '), isNull);
    });

    test('contraseña nueva: 8+ con letras y números', () {
      expect(Validar.contrasenaNueva('abc123'), isNotNull);
      expect(Validar.contrasenaNueva('soloLetras'), isNotNull);
      expect(Validar.contrasenaNueva('12345678'), isNotNull);
      expect(Validar.contrasenaNueva('BabyWolf2026'), isNull);
    });

    test('nombre de usuario', () {
      expect(Validar.apodo('ab'), isNotNull);
      expect(Validar.apodo('<script>'), isNotNull);
      expect(Validar.apodo('lector_uteq'), isNull);
    });
  });

  test('el registro enmascara el correo y no tiene dónde recibir la contraseña', () {
    LogSeguro.registrar('inicio_fallido', correo: 'abraham@bw.test');
    expect(LogSeguro.eventos.single.texto, 'inicio_fallido · a***m@bw.test');
    expect(LogSeguro.enmascarar('ab@x.mx'), '***@x.mx');
  });

  group('Sesion', () {
    late _Auth auth;
    late AlmacenMemoria almacen;
    late DateTime ahora;
    late Sesion sesion;

    setUp(() {
      auth = _Auth();
      almacen = AlmacenMemoria();
      ahora = DateTime(2026, 11, 6, 12);
      sesion = Sesion(cliente: MockClient(auth.responder), almacen: almacen, reloj: () => ahora);
    });

    test('SEG-01: entrar con la cuenta, rol leído de la tabla del blog', () async {
      await sesion.entrar('abraham@bw.test', 'Correcta123');
      expect(sesion.activa, isTrue);
      expect(sesion.cuenta!.uid, 'uid-1');
      expect(sesion.cuenta!.apodo, 'abraham');
      expect(sesion.esAdmin, isTrue);
      expect(almacen.valor, 'ref1'); // sólo el refresh token se guarda
      expect(LogSeguro.eventos.first.texto, 'inicio_sesion · a***m@bw.test');
    });

    test('SEG-02: contraseña incorrecta = mensaje genérico', () async {
      await expectLater(
        sesion.entrar('abraham@bw.test', 'Mala12345'),
        throwsA(isA<AuthFallo>().having((e) => e.mensaje, 'mensaje', 'Correo o contraseña incorrectos.')),
      );
      expect(sesion.activa, isFalse);
      expect(almacen.valor, isNull);
    });

    test('5 fallos bloquean 30 s sin llamar al servidor; luego se puede entrar', () async {
      for (var i = 0; i < 5; i++) {
        await expectLater(sesion.entrar('abraham@bw.test', 'Mala12345'), throwsA(isA<AuthFallo>()));
      }
      final antes = auth.pedidas.length;
      await expectLater(
        sesion.entrar('abraham@bw.test', 'Correcta123'),
        throwsA(isA<AuthFallo>().having((e) => e.mensaje, 'mensaje', startsWith('Demasiados intentos'))),
      );
      expect(auth.pedidas.length, antes);

      ahora = ahora.add(const Duration(seconds: 31));
      await sesion.entrar('abraham@bw.test', 'Correcta123');
      expect(sesion.activa, isTrue);
    });

    test('datos inválidos no llegan al servidor', () async {
      await expectLater(sesion.entrar('no-es-correo', 'x'), throwsA(isA<AuthFallo>()));
      expect(auth.pedidas, isEmpty);
    });

    test('sin conexión no cuenta como intento fallido', () async {
      final s = Sesion(
        cliente: MockClient((_) => throw const SocketException('sin red')),
        almacen: almacen,
        reloj: () => ahora,
      );
      await expectLater(s.entrar('abraham@bw.test', 'Correcta123'), throwsA(isA<AuthFallo>()));
      expect(s.limite.fallos, 0);
    });

    test('el token se renueva solo antes de vencer', () async {
      await sesion.entrar('abraham@bw.test', 'Correcta123');
      expect(await sesion.token(), 'acc1');
      ahora = ahora.add(const Duration(minutes: 59, seconds: 30));
      expect(await sesion.token(), 'acc2');
      expect(almacen.valor, 'ref2');
      expect(auth.refrescos, 1);
    });

    test('al reabrir la app se recupera la sesión guardada', () async {
      almacen.valor = 'ref1';
      await sesion.restaurar();
      expect(sesion.listo, isTrue);
      expect(sesion.activa, isTrue);
      expect(await sesion.token(), 'acc2');
    });

    test('refresh token inválido: se borra y queda sin sesión', () async {
      almacen.valor = 'viejo';
      await sesion.restaurar();
      expect(sesion.activa, isFalse);
      expect(almacen.valor, isNull);
    });

    test('al reabrir sin red se conserva el refresh token para después', () async {
      almacen.valor = 'ref1';
      final s = Sesion(cliente: MockClient((_) => throw const SocketException('sin red')), almacen: almacen);
      await s.restaurar();
      expect(s.listo, isTrue);
      expect(s.activa, isFalse);
      expect(almacen.valor, 'ref1');
    });

    test('cerrar sesión borra el token guardado', () async {
      await sesion.entrar('abraham@bw.test', 'Correcta123');
      await sesion.salir();
      expect(sesion.activa, isFalse);
      expect(almacen.valor, isNull);
      expect(auth.pedidas, contains('POST /auth/v1/logout'));
      await expectLater(sesion.token(), throwsA(isA<AuthFallo>()));
    });

    group('crear cuenta', () {
      test('con sesión inmediata', () async {
        expect(await sesion.registrarse('nuevo_lector', 'nuevo@bw.test', 'BabyWolf2026'), isTrue);
        expect(sesion.activa, isTrue);
      });

      test('si Supabase pide confirmar el correo, no entra', () async {
        expect(await sesion.registrarse('confirma', 'confirmar@bw.test', 'BabyWolf2026'), isFalse);
        expect(sesion.activa, isFalse);
      });

      test('nombre o correo repetido: mensaje que no revela cuál', () async {
        await expectLater(
          sesion.registrarse('abraham', 'repetido@bw.test', 'BabyWolf2026'),
          throwsA(isA<AuthFallo>().having((e) => e.mensaje, 'mensaje', contains('otro correo o nombre de usuario'))),
        );
      });

      test('contraseña débil no llega al servidor', () async {
        await expectLater(sesion.registrarse('lector', 'a@bw.test', '12345678'), throwsA(isA<AuthFallo>()));
        expect(auth.pedidas, isEmpty);
      });
    });
  });
}

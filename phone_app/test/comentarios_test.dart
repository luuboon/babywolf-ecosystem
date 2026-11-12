// Práctica 6: comentarios de una noticia (canal compartido entre teléfonos).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/comentarios/comentarios_api.dart';
import 'package:phone_app/core/supabase.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _fila(String id, String autor, String texto) => {
      'id': id,
      'author_id': autor,
      'content': texto,
      'created_at': '2026-11-06T18:30:00Z',
      'users': {'username': 'user_$autor'},
    };

void main() {
  test('reglas: vacío y más de 280 caracteres se rechazan', () {
    expect(ReglasComentario.validar('   '), isNotNull);
    expect(ReglasComentario.validar('a' * 281), isNotNull);
    expect(ReglasComentario.validar('a' * 280), isNull);
  });

  test('cada comentario trae autor y hora; el contador cuenta por autor', () {
    final lista = [
      Comentario.desdeJson(_fila('1', 'A', 'Hola')),
      Comentario.desdeJson(_fila('2', 'B', 'Hey')),
      Comentario.desdeJson(_fila('3', 'A', 'Otra vez')),
    ];
    expect(lista.first.autor, 'user_A');
    expect(lista.first.hora.isUtc, isFalse); // hora local del teléfono
    expect(ReglasComentario.conteo(lista), {'A': 2, 'B': 1});
  });

  test('sin el usuario embebido se muestra "Lector"', () {
    expect(Comentario.desdeJson({'id': '1', 'author_id': 'x', 'content': 'c'}).autor, 'Lector');
  });

  test('listar pide sólo los de esa noticia, en orden, y se puede leer sin sesión', () async {
    late http.Request pedida;
    final api = ComentariosApi(cliente: MockClient((r) async {
      pedida = r;
      return http.Response(jsonEncode([_fila('1', 'A', 'Hola')]), 200, headers: _json);
    }));
    final lista = await api.listar('post-1');
    expect(lista.single.texto, 'Hola');
    expect(pedida.url.queryParameters['post_id'], 'eq.post-1');
    expect(pedida.url.queryParameters['order'], 'created_at.asc');
    expect(pedida.headers.containsKey('Authorization'), isFalse);
  });

  test('publicar no manda el autor (lo pone la base) y valida antes de enviar', () async {
    final cuerpos = <Map<String, dynamic>>[];
    final api = ComentariosApi(cliente: MockClient((r) async {
      cuerpos.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response(jsonEncode([_fila('9', 'A', 'Buen artículo')]), 201, headers: _json);
    }));
    await expectLater(api.publicar('tok', 'post-1', '   '), throwsA(isA<ComentarioFallo>()));
    expect(cuerpos, isEmpty);

    final c = await api.publicar('tok', 'post-1', '  Buen artículo  ');
    expect(c.texto, 'Buen artículo');
    expect(cuerpos.single.keys.toSet(), {'id', 'post_id', 'content'}); // sin author_id
    expect(cuerpos.single['id'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(cuerpos.single['post_id'], 'post-1');
    expect(cuerpos.single['content'], 'Buen artículo');
  });

  test('borrar un comentario ajeno: la base devuelve 0 filas = no permitido', () async {
    final api = ComentariosApi(cliente: MockClient((_) async => http.Response('[]', 200, headers: _json)));
    expect(await api.borrar('tok', 'ajeno'), isFalse);
  });

  test('sin conexión no se finge el envío', () async {
    final api = ComentariosApi(cliente: MockClient((_) => throw const SocketException('sin red')));
    await expectLater(api.publicar('tok', 'post-1', 'Hola', esperar: (_) async {}), throwsA(isA<SinConexion>()));
  });
}

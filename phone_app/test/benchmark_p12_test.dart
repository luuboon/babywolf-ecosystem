// Práctica 12 · Fase 2 — tiempos de las operaciones de procesamiento de datos del cliente.
// Se ejecuta en la VM de Dart del equipo (JIT, no en el teléfono): sirve para COMPARAR tamaños,
// no como tiempo absoluto en un teléfono. Imprime líneas "BENCH ..." que recoge el script.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/models/post.dart';
import 'package:phone_app/services/busqueda.dart';

Map<String, dynamic> _json(int i) => {
      'id': '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      'author_id': '00000000-0000-0000-0000-0000000000a1',
      'title': 'Noticia $i',
      'slug': 'noticia-$i',
      'content': '${'Texto de noticia retro de consolas y videojuegos. ' * 10}$i',
      'category': const ['retro', 'tech', 'gaming', 'guides', 'opinion'][i % 5],
      'published': true,
      'created_at': '2026-11-11T12:00:00Z',
      'updated_at': '2026-11-11T12:00:00Z',
    };

double _medianaMs(void Function() f, int veces) {
  final t = <int>[];
  for (var i = 0; i < 3; i++) {
    f(); // calentamiento
  }
  for (var i = 0; i < veces; i++) {
    final s = Stopwatch()..start();
    f();
    t.add(s.elapsedMicroseconds);
  }
  t.sort();
  return t[t.length ~/ 2] / 1000;
}

void main() {
  test('BENCH búsqueda en el cliente (buscarPosts) según el número de noticias', () {
    for (final n in [8, 50, 500, 5000, 50000]) {
      final posts = [for (var i = 0; i < n; i++) Post.fromJson(_json(i))];
      final ms = _medianaMs(() => buscarPosts(posts, 'retro'), n >= 5000 ? 7 : 25);
      // ignore: avoid_print
      print('BENCH buscarPosts n=$n consulta="retro" mediana=${ms.toStringAsFixed(3)} ms');
    }
  });

  test('BENCH decodificar la respuesta de GET /api/posts: lista completa vs primera página', () {
    for (final n in [50, 4500]) {
      final cuerpo = jsonEncode([for (var i = 0; i < n; i++) _json(i)]);
      final ms = _medianaMs(() {
        final d = jsonDecode(cuerpo) as List;
        d.whereType<Map<String, dynamic>>().map(Post.fromJson).toList();
      }, n >= 1000 ? 9 : 25);
      // ignore: avoid_print
      print('BENCH decodificar n=$n bytes=${utf8.encode(cuerpo).length} mediana=${ms.toStringAsFixed(3)} ms');
    }
  });
}

// Barra de búsqueda del feed: qué noticias encuentra y en qué orden.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/models/post.dart';
import 'package:phone_app/services/busqueda.dart';

Post _post(String id, String titulo, {String texto = '', String cat = 'retro'}) => Post(
      id: id,
      title: titulo,
      slug: 'slug-$id',
      content: texto,
      category: cat,
      coverImageUrl: '',
      createdAt: DateTime(2026, 10, 1),
    );

List<String> _ids(List<Post> ps) => ps.map((p) => p.id).toList();

void main() {
  final feed = [
    _post('1', 'Zelda: Ocarina of Time cumple años', texto: 'El clásico de Nintendo 64.', cat: 'nintendo'),
    _post('2', 'Guía de emuladores', texto: 'Cómo jugar Zelda y otros clásicos en tu PC.', cat: 'guias'),
    _post('3', 'La Mega Drive y su música', texto: 'El chip YM2612.', cat: 'sega'),
    _post('4', 'Café y cartuchos', texto: 'Una tarde de Game Boy.', cat: 'retro'),
  ];

  test('sin texto devuelve el feed tal cual', () {
    expect(_ids(buscarPosts(feed, '')), ['1', '2', '3', '4']);
    expect(_ids(buscarPosts(feed, '   ')), ['1', '2', '3', '4']);
  });

  test('no distingue mayúsculas ni acentos', () {
    expect(_ids(buscarPosts(feed, 'CAFE')), ['4']);
    expect(_ids(buscarPosts(feed, 'guia')), ['2']);
    expect(_ids(buscarPosts(feed, 'música')), ['3']);
    expect(_ids(buscarPosts(feed, 'musica')), ['3']);
  });

  test('primero las que lo tienen en el título, luego en el texto', () {
    expect(_ids(buscarPosts(feed, 'zelda')), ['1', '2']);
  });

  test('cada palabra debe aparecer, en cualquier orden y campo', () {
    expect(_ids(buscarPosts(feed, 'nintendo zelda')), ['1']);
    expect(_ids(buscarPosts(feed, 'zelda  pc')), ['2']);
    expect(_ids(buscarPosts(feed, 'zelda sega')), isEmpty);
  });

  test('también busca en el tema', () {
    expect(_ids(buscarPosts(feed, 'sega')), ['3']);
  });

  test('sin coincidencias = lista vacía', () {
    expect(buscarPosts(feed, 'playstation'), isEmpty);
  });

  test('normalizar', () {
    expect(normalizar('  Ñandú   CAFÉ\n'), 'nandu cafe');
  });
}

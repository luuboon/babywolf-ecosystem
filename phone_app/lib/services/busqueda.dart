// Búsqueda de noticias en el feed.
//
// Las noticias ya llegan completas desde GET /api/posts, así que se buscan en
// el teléfono: es instantáneo y no gasta otra petición por cada letra.
//
// - No distingue mayúsculas ni acentos ("cafe" encuentra "Café").
// - Cada palabra escrita tiene que aparecer (en título, tema o texto).
// - Primero las que lo tienen en el título; dentro de cada grupo se respeta
//   el orden del feed (más recientes primero).

import '../models/post.dart';

List<Post> buscarPosts(List<Post> posts, String consulta) {
  final palabras = normalizar(consulta).split(' ').where((p) => p.isNotEmpty).toList();
  if (palabras.isEmpty) return posts;

  final enTitulo = <Post>[];
  final enTexto = <Post>[];
  for (final p in posts) {
    final titulo = normalizar(p.title);
    final todo = '$titulo ${normalizar(p.category)} ${normalizar(p.content)}';
    if (!palabras.every(todo.contains)) continue;
    (palabras.every(titulo.contains) ? enTitulo : enTexto).add(p);
  }
  return [...enTitulo, ...enTexto];
}

/// Minúsculas, sin acentos y con un solo espacio entre palabras.
String normalizar(String s) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = con.indexOf(c);
    b.write(i >= 0 ? sin[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

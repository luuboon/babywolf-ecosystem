// Consulta al blog BabyWolf: qué temas existen y cuántas noticias tiene cada uno.
//
// El reloj no inventa los temas ni el número de noticias: los saca de la misma
// API que alimenta al teléfono y a la Smart TV. Lo único que simula es el acto
// de leer, que sí es actividad del usuario y ningún emulador puede medir.

import 'dart:convert';

import 'package:http/http.dart' as http;

const String kApiBase = 'https://babywolf-blog-production.up.railway.app/api';

class ResumenBlog {
  /// Categorías reales, de la más poblada a la menos.
  final List<String> temas;

  /// Cuántas noticias publicadas tiene cada categoría.
  final Map<String, int> porTema;

  const ResumenBlog(this.temas, this.porTema);

  int get total => porTema.values.fold(0, (a, b) => a + b);

  /// Con qué quedarse si la API no responde: el reloj sigue funcionando y la
  /// demo no se cae, pero los contadores arrancan en cero.
  static const ResumenBlog vacio = ResumenBlog(
    ['retro', 'gaming', 'tech', 'opinion'],
    {},
  );
}

Future<ResumenBlog> consultarBlog() async {
  final res = await http
      .get(Uri.parse('$kApiBase/posts'))
      .timeout(const Duration(seconds: 12));

  if (res.statusCode != 200) {
    throw Exception('El servidor respondió ${res.statusCode}');
  }

  final decoded = jsonDecode(utf8.decode(res.bodyBytes));
  if (decoded is! List) throw Exception('Respuesta inesperada de la API');

  final porTema = <String, int>{};
  for (final p in decoded) {
    if (p is! Map) continue;
    final cat = p['category'];
    if (cat is! String || cat.isEmpty) continue;
    porTema[cat] = (porTema[cat] ?? 0) + 1;
  }

  if (porTema.isEmpty) return ResumenBlog.vacio;

  final temas = porTema.keys.toList()
    ..sort((a, b) => porTema[b]!.compareTo(porTema[a]!));

  return ResumenBlog(temas, porTema);
}

// Acceso a la API pública del blog BabyWolf y publicación de estado al hub.
//
// GET /api/posts es público: no lleva API key, así que no hay ningún secreto
// que ocultar en el repositorio.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../gatt_constants.dart';
import '../models/post.dart';

class BlogApi {
  static const String base =
      'https://babywolf-blog-production.up.railway.app/api';

  static const _timeout = Duration(seconds: 15);

  /// Noticias publicadas, más recientes primero (el backend ya las ordena).
  Future<List<Post>> posts() async {
    final res =
        await http.get(Uri.parse('$base/posts')).timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('El servidor respondió ${res.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) throw Exception('Respuesta inesperada de la API');

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  }
}

/// Avisa al hub qué noticia se está viendo, para que la Smart TV la muestre.
/// Si el hub no está corriendo, la app sigue funcionando sin sincronía.
Future<void> publicarSeleccion(Post post) async {
  final url = Uri.parse('http://$kHubHost:$kHubPort/state');
  try {
    await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'slug': post.slug, 'category': post.category}),
        )
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // La sincronía con la TV es un extra: nunca debe romper la lectura.
  }
}

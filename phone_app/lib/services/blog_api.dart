// Acceso a la API pública del blog BabyWolf y publicación de estado al hub.
//
// GET /api/posts es público: no lleva API key, así que no hay ningún secreto
// que ocultar en el repositorio.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../gatt_constants.dart';
import '../models/post.dart';

/// Error de la API con un mensaje que se puede mostrar tal cual al usuario:
/// no incluye el nombre del servidor ni detalles del sistema operativo.
class BlogApiException implements Exception {
  const BlogApiException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class BlogApi {
  /// [cliente] y [base] se pueden sustituir en las pruebas (Práctica 11).
  BlogApi({http.Client? cliente, String? base})
      : _c = cliente ?? http.Client(),
        _base = base ?? BlogApi.base;

  static const String base =
      'https://babywolf-blog-production.up.railway.app/api';

  static const _timeout = Duration(seconds: 15);

  final http.Client _c;
  final String _base;

  /// Noticias publicadas, más recientes primero (el backend ya las ordena).
  Future<List<Post>> posts() async {
    final http.Response res;
    try {
      res = await _c.get(Uri.parse('$_base/posts')).timeout(_timeout);
    } on SocketException {
      throw const BlogApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw const BlogApiException('El servidor no respondió a tiempo.');
    } on http.ClientException {
      throw const BlogApiException('No se pudo establecer la conexión.');
    }

    if (res.statusCode != 200) {
      throw BlogApiException('El servidor respondió ${res.statusCode}.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const BlogApiException('Respuesta inesperada de la API.');
    }
    if (decoded is! List) {
      throw const BlogApiException('Respuesta inesperada de la API.');
    }

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

// Práctica 6 (MobileConnect) — Comentarios de una noticia.
//
// Lo esencial de la práctica es que dos teléfonos se manden mensajes por un
// canal compartido, con emisor, hora y contador. En BabyWolf ese canal son
// los comentarios: cada noticia es una "sala" y cada lector, un emisor. Lo
// que escribe un teléfono aparece en el otro (la sección se actualiza cada
// pocos segundos).
//
// Se guardan en la tabla comments del blog (Supabase), con reglas RLS de
// 007_app_lectores.sql: cualquiera lee, sólo con sesión se comenta, nadie
// comenta a nombre de otro y sólo el autor (o el admin) borra.

import 'package:http/http.dart' as http;

import '../core/supabase.dart';

class Comentario {
  const Comentario({
    required this.id,
    required this.autorId,
    required this.autor,
    required this.texto,
    required this.hora,
  });

  final String id;
  final String autorId;
  final String autor;
  final String texto;
  final DateTime hora;

  factory Comentario.desdeJson(Map<String, dynamic> j) {
    final u = j['users'];
    return Comentario(
      id: j['id'] as String? ?? '',
      autorId: j['author_id'] as String? ?? '',
      autor: (u is Map ? u['username'] as String? : null) ?? 'Lector',
      texto: j['content'] as String? ?? '',
      hora: (DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now()).toLocal(),
    );
  }
}

/// Reglas que la app revisa antes de enviar (la base las repite).
class ReglasComentario {
  static const maxTexto = 280;

  static String? validar(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return 'No se pueden enviar comentarios vacíos';
    if (t.length > maxTexto) return 'Máximo $maxTexto caracteres';
    return null;
  }

  /// Contador por autor, para "Tus comentarios: N".
  static Map<String, int> conteo(List<Comentario> lista) {
    final c = <String, int>{};
    for (final m in lista) {
      c[m.autorId] = (c[m.autorId] ?? 0) + 1;
    }
    return c;
  }
}

class ComentarioFallo implements Exception {
  const ComentarioFallo(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class ComentariosApi {
  ComentariosApi({http.Client? cliente}) : _c = cliente ?? http.Client();

  final http.Client _c;
  static const _select = 'id,content,created_at,author_id,users(username)';

  /// Lectura pública: [token] puede ser null.
  Future<List<Comentario>> listar(String postId, {String? token}) async {
    final r = await Supabase.enviar(
      _c,
      Supabase.peticion(
        'GET',
        Supabase.rest('comments', {'select': _select, 'post_id': 'eq.$postId', 'order': 'created_at.asc'}),
        token: token,
      ),
    );
    final j = Supabase.json(r);
    if (r.statusCode != 200 || j is! List) throw ComentarioFallo(Supabase.detalle(r));
    return j.whereType<Map<String, dynamic>>().map(Comentario.desdeJson).toList();
  }

  /// El autor NO se manda: la base lo toma del token (author_id = auth.uid()).
  Future<Comentario> publicar(String token, String postId, String texto) async {
    final invalido = ReglasComentario.validar(texto);
    if (invalido != null) throw ComentarioFallo(invalido);
    final r = await Supabase.enviar(
      _c,
      Supabase.peticion(
        'POST',
        Supabase.rest('comments', {'select': _select}),
        token: token,
        devolverFilas: true,
        cuerpo: {'post_id': postId, 'content': texto.trim()},
      ),
    );
    final j = Supabase.json(r);
    if (r.statusCode != 201 || j is! List || j.isEmpty) {
      throw ComentarioFallo('No se publicó el comentario. ${Supabase.detalle(r)}');
    }
    return Comentario.desdeJson(j.first as Map<String, dynamic>);
  }

  /// true = se borró. false = la base no lo permitió (no es tuyo).
  Future<bool> borrar(String token, String id) async {
    final r = await Supabase.enviar(
      _c,
      Supabase.peticion('DELETE', Supabase.rest('comments', {'id': 'eq.$id'}), token: token, devolverFilas: true),
    );
    final j = Supabase.json(r);
    if (r.statusCode != 200) throw ComentarioFallo(Supabase.detalle(r));
    return j is List && j.isNotEmpty;
  }
}

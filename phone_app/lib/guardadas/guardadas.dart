// Práctica 4 — Noticias guardadas: entidad, DAO y estado de la app.
//
// Equivalencias con Room:
//   Guardada      → @Entity
//   GuardadaDao   → @Dao (insertar, obtenerTodas, actualizarNota, eliminar)
//   Guardadas     → el ViewModel que usan las pantallas

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/post.dart';
import 'base_datos.dart';

class Guardada {
  const Guardada({this.id, required this.post, this.nota = '', required this.guardadaEn});

  final int? id;
  final Post post;
  final String nota;
  final DateTime guardadaEn;

  static const maxNota = 500;

  /// null = válida.
  static String? validarNota(String nota) =>
      nota.trim().length > maxNota ? 'La nota admite hasta $maxNota caracteres' : null;

  Guardada conNota(String n) => Guardada(id: id, post: post, nota: n.trim(), guardadaEn: guardadaEn);

  Map<String, Object?> aMapa() => {
        'id': id,
        'post_id': post.id,
        'slug': post.slug,
        'titulo': post.title,
        'categoria': post.category,
        'contenido': post.content,
        'portada_url': post.coverImageUrl,
        'publicada': post.createdAt.toIso8601String(),
        'nota': nota,
        'guardada_en': guardadaEn.toIso8601String(),
      };

  factory Guardada.desdeMapa(Map<String, Object?> m) => Guardada(
        id: m['id'] as int?,
        post: Post(
          id: m['post_id'] as String,
          title: m['titulo'] as String,
          slug: m['slug'] as String,
          content: m['contenido'] as String,
          category: m['categoria'] as String,
          coverImageUrl: m['portada_url'] as String? ?? '',
          createdAt: DateTime.tryParse(m['publicada'] as String? ?? '') ?? DateTime(2000),
        ),
        nota: m['nota'] as String? ?? '',
        guardadaEn: DateTime.tryParse(m['guardada_en'] as String? ?? '') ?? DateTime.now(),
      );
}

class GuardadaDao {
  GuardadaDao(this._db);

  final Database _db;
  static const _tabla = 'guardadas';

  /// INSERT — devuelve el id. Si la noticia ya estaba guardada no la duplica
  /// y devuelve 0.
  Future<int> insertar(Guardada g) =>
      _db.insert(_tabla, g.aMapa()..remove('id'), conflictAlgorithm: ConflictAlgorithm.ignore);

  /// SELECT — la más reciente primero.
  Future<List<Guardada>> obtenerTodas() async {
    final filas = await _db.query(_tabla, orderBy: 'guardada_en DESC, id DESC');
    return filas.map(Guardada.desdeMapa).toList();
  }

  Future<Guardada?> porPostId(String postId) async {
    final filas = await _db.query(_tabla, where: 'post_id = ?', whereArgs: [postId], limit: 1);
    return filas.isEmpty ? null : Guardada.desdeMapa(filas.first);
  }

  /// UPDATE — devuelve cuántas filas cambió (0 si ya no existe).
  Future<int> actualizarNota(String postId, String nota) =>
      _db.update(_tabla, {'nota': nota.trim()}, where: 'post_id = ?', whereArgs: [postId]);

  /// DELETE — devuelve cuántas filas borró.
  Future<int> eliminar(String postId) => _db.delete(_tabla, where: 'post_id = ?', whereArgs: [postId]);
}

/// Estado compartido: la pestaña "Guardadas" y el botón de marcador del
/// detalle de una noticia ven siempre lo mismo.
class Guardadas extends ChangeNotifier {
  Guardadas({Future<GuardadaDao> Function()? abrirDao, DateTime Function()? reloj})
      : _abrirDao = abrirDao ?? (() async => GuardadaDao(await BaseDatos.abrir())),
        _reloj = reloj ?? DateTime.now;

  final Future<GuardadaDao> Function() _abrirDao;
  final DateTime Function() _reloj;
  GuardadaDao? _dao;
  List<Guardada> _lista = const [];
  bool _cargada = false;

  List<Guardada> get lista => _lista;
  bool get cargada => _cargada;

  bool esta(String postId) => _lista.any((g) => g.post.id == postId);

  Guardada? de(String postId) {
    for (final g in _lista) {
      if (g.post.id == postId) return g;
    }
    return null;
  }

  Future<GuardadaDao> _d() async => _dao ??= await _abrirDao();

  Future<void> cargar() async {
    _lista = await (await _d()).obtenerTodas();
    _cargada = true;
    notifyListeners();
  }

  Future<void> guardar(Post post) async {
    await (await _d()).insertar(Guardada(post: post, guardadaEn: _reloj()));
    await cargar();
  }

  Future<void> quitar(String postId) async {
    await (await _d()).eliminar(postId);
    await cargar();
  }

  /// Lanza [ArgumentError] si la nota no es válida.
  Future<void> cambiarNota(String postId, String nota) async {
    final invalida = Guardada.validarNota(nota);
    if (invalida != null) throw ArgumentError(invalida);
    await (await _d()).actualizarNota(postId, nota);
    await cargar();
  }
}

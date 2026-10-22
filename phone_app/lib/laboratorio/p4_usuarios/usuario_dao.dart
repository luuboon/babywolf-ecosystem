// Práctica 4 — DAO de usuarios (equivale al @Dao de Room).
//
// Los nombres siguen los de la práctica: el botón "VER usuarios" llama a
// dao.obtenerTodos().

import 'package:sqflite/sqflite.dart';

import 'usuario.dart';

class UsuarioDao {
  UsuarioDao(this._db);

  final Database _db;
  static const _tabla = 'usuarios';

  /// INSERT — devuelve el id asignado.
  Future<int> insertar(Usuario u) => _db.insert(_tabla, u.aMapa()..remove('id'));

  /// SELECT * — todos los usuarios, por orden de registro.
  Future<List<Usuario>> obtenerTodos() async {
    final filas = await _db.query(_tabla, orderBy: 'id ASC');
    return filas.map(Usuario.desdeMapa).toList();
  }

  Future<Usuario?> obtenerPorId(int id) async {
    final filas = await _db.query(_tabla, where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : Usuario.desdeMapa(filas.first);
  }

  /// UPDATE — devuelve cuántas filas cambió (0 si el id no existe).
  Future<int> actualizar(Usuario u) {
    if (u.id == null) throw ArgumentError('Para actualizar se necesita el id');
    return _db.update(_tabla, u.aMapa()..remove('id'), where: 'id = ?', whereArgs: [u.id]);
  }

  /// DELETE — devuelve cuántas filas borró.
  Future<int> eliminar(int id) => _db.delete(_tabla, where: 'id = ?', whereArgs: [id]);
}

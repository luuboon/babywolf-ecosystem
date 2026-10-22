// Práctica 4 — Base de datos SQLite local (equivale a la @Database de Room).
//
// La práctica pide Room, que es la capa de Android/Kotlin sobre SQLite. Esta
// app es Flutter, así que se usa sqflite: el mismo motor SQLite del teléfono,
// con la base de datos guardada en el almacenamiento privado de la app.

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class BaseDatos {
  static const nombreArchivo = 'babywolf_usuarios.db';

  /// Versión del esquema. Cada cambio de estructura sube este número y
  /// agrega su paso en [_migrar].
  static const version = 1;

  static Database? _db;

  /// [factory] y [ruta] sólo se pasan en las pruebas (SQLite en memoria).
  static Future<Database> abrir({DatabaseFactory? factory, String? ruta}) async {
    if (_db != null && factory == null) return _db!;
    final f = factory ?? databaseFactory;
    final destino = ruta ?? p.join(await f.getDatabasesPath(), nombreArchivo);
    final db = await f.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, v) => _crear(db),
        onUpgrade: _migrar,
      ),
    );
    if (factory == null) _db = db;
    return db;
  }

  static Future<void> _crear(Database db) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre    TEXT    NOT NULL,
        edad      INTEGER NOT NULL,
        profesion TEXT    NOT NULL
      )
    ''');
  }

  static Future<void> _migrar(Database db, int anterior, int nueva) async {
    // Sin migraciones todavía: el esquema está en su versión 1.
  }
}

// Práctica 4 — Base de datos SQLite local (equivale a la @Database de Room).
//
// La práctica pide Room, que es la capa de Android/Kotlin sobre SQLite. Esta
// app es Flutter, así que se usa sqflite: el mismo motor SQLite del teléfono,
// con el archivo guardado en el almacenamiento privado de la app.
//
// En BabyWolf la entidad no es "usuario" sino "noticia guardada": las cuentas
// de usuario ya viven en Supabase (son las de la web) y duplicarlas en el
// teléfono no tendría uso. Lo que sí tiene sentido guardar localmente es lo
// que el lector quiere conservar para leer sin internet.

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class BaseDatos {
  static const nombreArchivo = 'babywolf_local.db';

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

  /// Se guarda la noticia COMPLETA (no sólo el enlace) para poder leerla sin
  /// conexión. post_id es único: la misma noticia no se guarda dos veces.
  static Future<void> _crear(Database db) async {
    await db.execute('''
      CREATE TABLE guardadas (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id     TEXT    NOT NULL UNIQUE,
        slug        TEXT    NOT NULL,
        titulo      TEXT    NOT NULL,
        categoria   TEXT    NOT NULL,
        contenido   TEXT    NOT NULL,
        portada_url TEXT    NOT NULL DEFAULT '',
        publicada   TEXT    NOT NULL,
        nota        TEXT    NOT NULL DEFAULT '',
        guardada_en TEXT    NOT NULL
      )
    ''');
  }

  /// Sin migraciones todavía: la versión 1 es la primera de esta tabla.
  static Future<void> _migrar(Database db, int anterior, int nueva) async {}
}

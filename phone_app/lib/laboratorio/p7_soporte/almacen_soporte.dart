// Práctica 7 — Lo que la mesa de ayuda guarda en el teléfono.
//
// - La sesión (token de 12 h y datos del participante), para que al cerrar y
//   abrir la app se siga dentro (TC08) sin volver a usar la invitación, que
//   es de un solo uso.
// - Operaciones pendientes: si se pierde la conexión al guardar (TC07), la
//   operación queda aquí y se reenvía al volver la red.
//
// Base SQLite propia de la práctica, separada de la de usuarios (práctica 4)
// para no mezclar sus migraciones.

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'modelos.dart';
import 'soporte_api.dart';

class Pendiente {
  const Pendiente(this.id, this.tipo, this.datos, this.creado);
  final int id;
  final String tipo; // crear_reporte | enviar_mensaje | actualizar_reporte
  final Map<String, dynamic> datos;
  final DateTime creado;

  String get descripcion => switch (tipo) {
        'crear_reporte' => 'Alta de reporte "${datos['equipo'] ?? ''}"',
        'actualizar_reporte' => 'Cambio en ${datos['id'] ?? 'reporte'}',
        _ => 'Mensaje "${datos['texto'] ?? ''}"',
      };
}

class AlmacenSoporte {
  AlmacenSoporte(this._db);

  final Database _db;
  static Database? _compartida;

  static Future<AlmacenSoporte> abrir({DatabaseFactory? factory, String? ruta}) async {
    if (_compartida != null && factory == null) return AlmacenSoporte(_compartida!);
    final f = factory ?? databaseFactory;
    final destino = ruta ?? p.join(await f.getDatabasesPath(), 'babywolf_soporte.db');
    final db = await f.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE sesion (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
          await db.execute('''
            CREATE TABLE pendientes (
              id     INTEGER PRIMARY KEY AUTOINCREMENT,
              tipo   TEXT NOT NULL,
              datos  TEXT NOT NULL,
              creado TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    if (factory == null) _compartida = db;
    return AlmacenSoporte(db);
  }

  // ── Sesión ───────────────────────────────────────────────

  Future<void> guardarSesion(Sesion s) async {
    await _db.insert('sesion', {'clave': 'token', 'valor': s.token}, conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.insert('sesion', {'clave': 'yo', 'valor': jsonEncode(s.yo.aJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Sesion?> leerSesion() async {
    final filas = await _db.query('sesion');
    final m = {for (final f in filas) f['clave'] as String: f['valor'] as String};
    if (m['token'] == null || m['yo'] == null) return null;
    return Sesion(m['token']!, Participante.desdeJson(jsonDecode(m['yo']!) as Map<String, dynamic>));
  }

  Future<void> borrarSesion() async {
    await _db.delete('sesion');
    await _db.delete('pendientes');
  }

  // ── Pendientes (TC07) ────────────────────────────────────

  Future<void> agregarPendiente(String tipo, Map<String, dynamic> datos) => _db.insert('pendientes', {
        'tipo': tipo,
        'datos': jsonEncode(datos),
        'creado': DateTime.now().toIso8601String(),
      });

  Future<List<Pendiente>> pendientes() async {
    final filas = await _db.query('pendientes', orderBy: 'id ASC');
    return [
      for (final f in filas)
        Pendiente(
          f['id'] as int,
          f['tipo'] as String,
          jsonDecode(f['datos'] as String) as Map<String, dynamic>,
          DateTime.tryParse(f['creado'] as String) ?? DateTime.now(),
        ),
    ];
  }

  Future<void> quitarPendiente(int id) => _db.delete('pendientes', where: 'id = ?', whereArgs: [id]);
}

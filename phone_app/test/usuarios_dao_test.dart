// Práctica 4: casos 1 a 4 sobre SQLite real (en memoria, con sqflite_common_ffi).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/laboratorio/p4_usuarios/base_datos.dart';
import 'package:phone_app/laboratorio/p4_usuarios/usuario.dart';
import 'package:phone_app/laboratorio/p4_usuarios/usuario_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late UsuarioDao dao;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: inMemoryDatabasePath);
    await db.delete('usuarios');
    dao = UsuarioDao(db);
  });

  test('Caso 1 — insertar tres estudiantes', () async {
    final ids = [
      await dao.insertar(const Usuario(nombre: 'Abraham Camacho', edad: 21, profesion: 'IDGS')),
      await dao.insertar(const Usuario(nombre: 'Gloria Pérez', edad: 20, profesion: 'Mecatrónica')),
      await dao.insertar(const Usuario(nombre: 'Luis Durán', edad: 22, profesion: 'Redes')),
    ];
    expect(ids.toSet().length, 3);
  });

  test('Caso 2 — obtenerTodos devuelve los registros en orden', () async {
    await dao.insertar(const Usuario(nombre: 'A', edad: 20, profesion: 'IDGS'));
    await dao.insertar(const Usuario(nombre: 'B', edad: 21, profesion: 'Redes'));
    final todos = await dao.obtenerTodos();
    expect(todos.map((u) => u.nombre), ['A', 'B']);
  });

  test('Caso 3 — actualizar la carrera de un estudiante', () async {
    final id = await dao.insertar(const Usuario(nombre: 'Gloria', edad: 20, profesion: 'Mecatrónica'));
    final u = (await dao.obtenerPorId(id))!;
    expect(await dao.actualizar(u.copiar(profesion: 'IDGS')), 1);
    expect((await dao.obtenerPorId(id))!.profesion, 'IDGS');
  });

  test('eliminar', () async {
    final id = await dao.insertar(const Usuario(nombre: 'X', edad: 30, profesion: 'Y'));
    expect(await dao.eliminar(id), 1);
    expect(await dao.obtenerPorId(id), isNull);
  });

  test('validaciones del formulario', () {
    expect(ValidadorUsuario.nombre('  '), isNotNull);
    expect(ValidadorUsuario.edad('abc'), isNotNull);
    expect(ValidadorUsuario.edad('10'), isNotNull);
    expect(ValidadorUsuario.edad('21'), isNull);
    expect(ValidadorUsuario.profesion(''), isNotNull);
  });

  group('Caso 4 — nuevo campo correo', () {
    test('se inserta, se consulta y se actualiza', () async {
      final id = await dao.insertar(
          const Usuario(nombre: 'Ana', edad: 21, profesion: 'IDGS', correo: 'ana@uteq.edu.mx'));
      final u = (await dao.obtenerPorId(id))!;
      expect(u.correo, 'ana@uteq.edu.mx');
      await dao.actualizar(u.copiar(correo: 'ana.r@uteq.edu.mx'));
      expect((await dao.obtenerTodos()).single.correo, 'ana.r@uteq.edu.mx');
    });

    test('validación del correo', () {
      expect(ValidadorUsuario.correo(''), isNotNull);
      expect(ValidadorUsuario.correo('ana@'), isNotNull);
      expect(ValidadorUsuario.correo('ana@uteq.edu.mx'), isNull);
    });

    test('una base de la versión 1 migra sin perder datos', () async {
      final dir = Directory.systemTemp.createTempSync('bw_p4_');
      final ruta = '${dir.path}/v1.db';
      // Base "vieja": la estructura que tenía la app antes del Caso 4.
      final v1 = await databaseFactoryFfi.openDatabase(ruta,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute('CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                  'nombre TEXT NOT NULL, edad INTEGER NOT NULL, profesion TEXT NOT NULL)');
              await db.insert('usuarios', {'nombre': 'Previo', 'edad': 20, 'profesion': 'Redes'});
            },
          ));
      await v1.close();

      final v2 = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      final dao2 = UsuarioDao(v2);
      final previo = (await dao2.obtenerTodos()).single;
      expect(previo.nombre, 'Previo');
      expect(previo.correo, ''); // la columna nueva llega vacía
      await dao2.insertar(const Usuario(nombre: 'Nuevo', edad: 22, profesion: 'IDGS', correo: 'n@uteq.edu.mx'));
      expect((await dao2.obtenerTodos()).length, 2);
      await v2.close();
      dir.deleteSync(recursive: true);
    });
  });
}

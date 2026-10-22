// Práctica 4: casos 1 a 3 sobre SQLite real (en memoria, con sqflite_common_ffi).
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
}

// Práctica 13/14 · Fase 3 — Persistencia (AUT-06): noticias guardadas en SQLite
// real (sqflite_common_ffi), con un archivo en disco para comprobar que los
// datos sobreviven al cerrar y reabrir la base.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/guardadas/base_datos.dart';
import 'package:phone_app/guardadas/guardadas.dart';
import 'package:phone_app/models/post.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Post _post(String id) => Post(
      id: id,
      title: 'Noticia $id',
      slug: 'slug-$id',
      content: 'Contenido completo $id',
      category: 'retro',
      coverImageUrl: '',
      createdAt: DateTime(2026, 10, 1),
    );

Guardada _g(String id, {String nota = ''}) =>
    Guardada(post: _post(id), nota: nota, guardadaEn: DateTime(2026, 11, 18));

void main() {
  setUpAll(sqfliteFfiInit);

  group('AUT-06 · persistencia de noticias guardadas', () {
    late Directory dir;
    late String ruta;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('aut06_');
      ruta = '${dir.path}/babywolf_test.db';
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('AUT-06a el registro guardado se lee igual que se escribió', () async {
      final db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      final dao = GuardadaDao(db);
      expect(await dao.insertar(_g('a', nota: 'leer luego')), greaterThan(0));
      final leida = await dao.porPostId('a');
      expect(leida, isNotNull);
      expect(leida!.post.title, 'Noticia a');
      expect(leida.post.content, 'Contenido completo a');
      expect(leida.nota, 'leer luego');
      await db.close();
    });

    test('AUT-06b la misma noticia no se duplica: el segundo insert devuelve 0 y queda una sola fila', () async {
      final db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      final dao = GuardadaDao(db);
      expect(await dao.insertar(_g('a')), greaterThan(0));
      expect(await dao.insertar(_g('a')), 0);
      expect((await dao.obtenerTodas()).length, 1);
      await db.close();
    });

    test('AUT-06c los datos sobreviven al cerrar y reabrir la base (archivo en disco)', () async {
      var db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      await GuardadaDao(db).insertar(_g('a'));
      await GuardadaDao(db).insertar(_g('b'));
      await db.close();

      db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      final todas = await GuardadaDao(db).obtenerTodas();
      expect(todas.map((g) => g.post.id).toSet(), {'a', 'b'});
      await db.close();
    });

    test('AUT-06d actualizar la nota y eliminar devuelven cuántas filas cambiaron (0 si ya no existe)', () async {
      final db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      final dao = GuardadaDao(db);
      await dao.insertar(_g('a'));
      expect(await dao.actualizarNota('a', '  nueva nota  '), 1);
      expect((await dao.porPostId('a'))!.nota, 'nueva nota');
      expect(await dao.eliminar('a'), 1);
      expect(await dao.eliminar('a'), 0);
      expect(await dao.actualizarNota('a', 'x'), 0);
      expect(await dao.porPostId('a'), isNull);
      await db.close();
    });

    test('AUT-06e el estado compartido Guardadas guarda, ve lo mismo que la base y quita', () async {
      final db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
      final estado = Guardadas(abrirDao: () async => GuardadaDao(db), reloj: () => DateTime(2026, 11, 18));
      await estado.cargar();
      await estado.guardar(_post('a'));
      expect(estado.lista.map((g) => g.post.id), ['a']);
      expect((await GuardadaDao(db).obtenerTodas()).length, 1, reason: 'lo que ve la pantalla está en la base');
      await estado.quitar('a');
      expect(estado.lista, isEmpty);
      expect(await GuardadaDao(db).obtenerTodas(), isEmpty);
      await db.close();
    });
  });
}

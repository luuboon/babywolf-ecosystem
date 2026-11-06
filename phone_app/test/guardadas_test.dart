// Práctica 4: noticias guardadas sobre SQLite real (sqflite_common_ffi).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/guardadas/base_datos.dart';
import 'package:phone_app/guardadas/guardadas.dart';
import 'package:phone_app/models/post.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Post _post(String id, {String titulo = 'Noticia', String cat = 'retro'}) => Post(
      id: id,
      title: titulo,
      slug: 'slug-$id',
      content: 'Contenido completo de $titulo',
      category: cat,
      coverImageUrl: '',
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  late GuardadaDao dao;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final db = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: inMemoryDatabasePath);
    await db.delete('guardadas');
    dao = GuardadaDao(db);
  });

  test('insertar (guardar) tres noticias', () async {
    final ids = [
      await dao.insertar(Guardada(post: _post('a'), guardadaEn: DateTime(2026, 11, 1))),
      await dao.insertar(Guardada(post: _post('b'), guardadaEn: DateTime(2026, 11, 2))),
      await dao.insertar(Guardada(post: _post('c'), guardadaEn: DateTime(2026, 11, 3))),
    ];
    expect(ids.toSet().length, 3);
  });

  test('consultar: la más reciente primero y con la noticia completa', () async {
    await dao.insertar(Guardada(post: _post('a', titulo: 'Vieja'), guardadaEn: DateTime(2026, 11, 1)));
    await dao.insertar(Guardada(post: _post('b', titulo: 'Nueva'), guardadaEn: DateTime(2026, 11, 2)));
    final todas = await dao.obtenerTodas();
    expect(todas.map((g) => g.post.title), ['Nueva', 'Vieja']);
    expect(todas.first.post.content, 'Contenido completo de Nueva'); // se lee sin internet
  });

  test('la misma noticia no se guarda dos veces', () async {
    await dao.insertar(Guardada(post: _post('a'), guardadaEn: DateTime(2026, 11, 1)));
    expect(await dao.insertar(Guardada(post: _post('a'), guardadaEn: DateTime(2026, 11, 2))), 0);
    expect((await dao.obtenerTodas()).length, 1);
  });

  test('modificar la nota personal', () async {
    await dao.insertar(Guardada(post: _post('a'), guardadaEn: DateTime(2026, 11, 1)));
    expect(await dao.actualizarNota('a', '  Releer antes del examen  '), 1);
    expect((await dao.porPostId('a'))!.nota, 'Releer antes del examen');
    expect(await dao.actualizarNota('no-existe', 'x'), 0);
  });

  test('eliminar', () async {
    await dao.insertar(Guardada(post: _post('a'), guardadaEn: DateTime(2026, 11, 1)));
    expect(await dao.eliminar('a'), 1);
    expect(await dao.porPostId('a'), isNull);
  });

  test('validación de la nota', () {
    expect(Guardada.validarNota('a' * 500), isNull);
    expect(Guardada.validarNota('a' * 501), isNotNull);
  });

  test('persistencia: los datos siguen al cerrar y abrir la base', () async {
    final dir = Directory.systemTemp.createTempSync('bw_guardadas_');
    final ruta = '${dir.path}/babywolf_local.db';
    final db1 = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
    await GuardadaDao(db1).insertar(Guardada(post: _post('p'), nota: 'mía', guardadaEn: DateTime(2026, 11, 5)));
    await db1.close();

    final db2 = await BaseDatos.abrir(factory: databaseFactoryFfi, ruta: ruta);
    final g = (await GuardadaDao(db2).obtenerTodas()).single;
    expect(g.post.id, 'p');
    expect(g.nota, 'mía');
    await db2.close();
    dir.deleteSync(recursive: true);
  });

  test('Guardadas (estado de la app): guardar, nota y quitar avisan a las pantallas', () async {
    final estado = Guardadas(abrirDao: () async => dao, reloj: () => DateTime(2026, 11, 6));
    var avisos = 0;
    estado.addListener(() => avisos++);
    await estado.cargar();
    await estado.guardar(_post('x'));
    expect(estado.esta('x'), isTrue);
    await estado.cambiarNota('x', 'Para el fin de semana');
    expect(estado.de('x')!.nota, 'Para el fin de semana');
    await expectLater(estado.cambiarNota('x', 'a' * 501), throwsArgumentError);
    await estado.quitar('x');
    expect(estado.esta('x'), isFalse);
    expect(avisos, greaterThanOrEqualTo(4));
  });
}

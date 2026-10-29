// Práctica 10: cómo interpreta la app las respuestas de la base.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/laboratorio/p10_incidencias/incidencias_api.dart';
import 'package:phone_app/laboratorio/p10_incidencias/incidencias_screen.dart';

void main() {
  test('fila nueva que viola una regla (SEG-04, SEG-09) = rechazada', () {
    final r = Resultado.desdeRespuesta(403,
        '{"code":"42501","message":"new row violates row-level security policy for table \\"incidencias\\""}');
    expect(r.permitido, isFalse);
    expect(r.detalle, contains('42501'));
  });

  test('sin sesión (SEG-10) = rechazada', () {
    final r = Resultado.desdeRespuesta(401, '{"code":"42501","message":"permission denied for table incidencias"}');
    expect(r.permitido, isFalse);
    expect(r.detalle, contains('permission denied'));
  });

  test('leer, modificar o borrar algo ajeno (SEG-05/06/07) = 0 filas = rechazada', () {
    final r = Resultado.desdeRespuesta(200, '[]');
    expect(r.permitido, isFalse);
    expect(r.filas, 0);
  });

  test('operación propia (SEG-03, SEG-08) = permitida', () {
    final r = Resultado.desdeRespuesta(201, '[{"id":"x","titulo":"t","creado_por":"a"}]');
    expect(r.permitido, isTrue);
    expect(Incidencia.desdeJson(r.datos.single).creadoPor, 'a');
  });

  test('el UID se lee del JWT', () {
    String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    final jwt = '${b64({'alg': 'HS256'})}.${b64({'sub': 'aaaa-1'})}.firma';
    expect(SesionSupabase.uidDelToken(jwt), 'aaaa-1');
    expect(SesionSupabase.uidDelToken('basura'), isNull);
  });

  test('sólo se aceptan UUID en los campos del otro usuario', () {
    expect(IncidenciasApi.esUuid('aaaaaaaa-0000-0000-0000-00000000000a'), isTrue);
    expect(IncidenciasApi.esUuid("' or 1=1 --"), isFalse);
  });

  test('una fila de la matriz pasa cuando lo obtenido coincide con lo esperado', () {
    const rechazo = Resultado(permitido: false, codigo: 403, filas: 0, detalle: '42501');
    expect(Registro(DateTime(2026), 'SEG-04', 'x', false, rechazo).pasa, isTrue);
    expect(Registro(DateTime(2026), 'SEG-08', 'x', true, rechazo).pasa, isFalse);
    expect(Registro(DateTime(2026), 'SEG-05', 'x', false, Resultado.sinConexion).pasa, isFalse);
  });
}

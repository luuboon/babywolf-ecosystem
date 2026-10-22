// Práctica 7: validaciones y reglas de rol del lado de la app.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/laboratorio/p7_soporte/modelos.dart';
import 'package:phone_app/laboratorio/p7_soporte/soporte_api.dart';

void main() {
  test('TC02 — equipo y descripción obligatorios', () {
    expect(ValidadorReporte.equipo(''), isNotNull);
    expect(ValidadorReporte.descripcion('   '), isNotNull);
    expect(ValidadorReporte.equipo('Laptop 3'), isNull);
  });

  test('ID opcional con formato REPnnn', () {
    expect(ValidadorReporte.id(''), isNull);
    expect(ValidadorReporte.id('rep001'), isNull);
    expect(ValidadorReporte.id('REP1'), isNotNull);
  });

  test('tiempo real sólo para admin y agente', () {
    expect(puedeMonitorear(kRolAdmin), isTrue);
    expect(puedeMonitorear(kRolAgente), isTrue);
    expect(puedeMonitorear(kRolUsuario), isFalse);
    expect(puedeAdministrar(kRolAdminTemporal), isTrue);
    expect(puedeAdministrar(kRolAgente), isFalse);
  });

  test('sólo se aceptan URLs de invitación firmadas', () {
    expect(SoporteApi.urlInvitacion('https://x.app/api/soporte/unirse?inv=a&rol=agente&exp=1&sig=z'), isNotNull);
    expect(SoporteApi.urlInvitacion('https://x.app/api/soporte/unirse?inv=a'), isNull);
    expect(SoporteApi.urlInvitacion('hola'), isNull);
  });

  test('el reporte del servidor se interpreta', () {
    final r = Reporte.desdeJson({
      'id': 'REP001',
      'equipo': 'Laptop',
      'descripcion': 'No enciende',
      'prioridad': 'Alta',
      'estado': 'asignado',
      'solicitante_id': 'u1',
      'agente_id': null,
      'directo_admin': false,
      'updated_at': '2026-10-22T12:00:00Z',
    });
    expect(r.prioridad, 'Alta');
    expect(r.agenteId, isNull);
  });
}

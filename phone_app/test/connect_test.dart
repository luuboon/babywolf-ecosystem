// Práctica 6: reglas de MobileConnect.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/laboratorio/p6_connect/connect_api.dart';

void main() {
  test('no se envían mensajes vacíos ni demasiado largos', () {
    expect(ReglasConnect.validar(''), isNotNull);
    expect(ReglasConnect.validar('   \n '), isNotNull);
    expect(ReglasConnect.validar('x' * 281), isNotNull);
    expect(ReglasConnect.validar('hola'), isNull);
  });

  test('el cliente rechaza el vacío sin llamar al servidor', () async {
    await expectLater(ConnectApi(base: 'http://0.0.0.0:1').enviar('LAB-1', 'A', 'Pixel', '  '),
        throwsA(isA<ConnectException>()));
  });

  test('el mensaje del servidor trae emisor y hora', () {
    final m = MensajeConnect.desdeJson({
      'id': 3,
      'emisor': 'B',
      'dispositivo': 'Pixel B',
      'texto': 'hola',
      'hora': '2026-10-22T23:19:18Z',
    });
    expect(m.emisor, 'B');
    expect(m.hora.isUtc, isTrue);
  });
}

// Práctica 5: validación de entradas y manejo seguro de credenciales.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/laboratorio/p5_acceso/log_seguro.dart';
import 'package:phone_app/laboratorio/p5_acceso/validador_acceso.dart';

void main() {
  group('usuario', () {
    test('vacío y sólo espacios se rechazan', () {
      expect(ValidadorAcceso.usuario(''), isNotNull);
      expect(ValidadorAcceso.usuario('     '), 'El usuario no puede contener solo espacios');
    });
    test('más de 30 caracteres se rechaza', () {
      expect(ValidadorAcceso.usuario('a' * 31), isNotNull);
      expect(ValidadorAcceso.usuario('a' * 30), isNull);
    });
    test('caracteres de inyección se rechazan', () {
      expect(ValidadorAcceso.usuario("admin' OR '1'='1"), isNotNull);
      expect(ValidadorAcceso.usuario('<script>'), isNotNull);
    });
  });

  group('contraseña', () {
    test('vacía y menor de 8 se rechazan', () {
      expect(ValidadorAcceso.contrasena(''), isNotNull);
      expect(ValidadorAcceso.contrasena('1234567'), isNotNull);
      expect(ValidadorAcceso.contrasena('12345678'), isNull);
    });
    test('más de 64 caracteres se rechaza', () {
      expect(ValidadorAcceso.contrasena('x' * 65), isNotNull);
    });
  });

  test('las credenciales de prueba dan acceso; cualquier otra no', () {
    expect(CredencialesPrueba.verificar(' alumno.uteq ', 'BabyWolf2026'), isTrue);
    expect(CredencialesPrueba.verificar('alumno.uteq', 'babywolf2026'), isFalse);
    expect(CredencialesPrueba.verificar('otro', 'BabyWolf2026'), isFalse);
  });

  test('el registro nunca contiene la contraseña y enmascara el usuario', () {
    LogSeguro.limpiar();
    LogSeguro.registrar('acceso_denegado', usuario: 'alumno.uteq');
    final texto = LogSeguro.eventos.map((e) => e.texto).join('\n');
    expect(texto, isNot(contains('BabyWolf2026')));
    expect(texto, isNot(contains('alumno.uteq')));
    expect(texto, contains('a***q'));
  });

  test('cinco fallos bloquean 30 s', () {
    var ahora = DateTime(2026, 10, 22, 12);
    final l = LimiteIntentos(reloj: () => ahora);
    for (var i = 0; i < 5; i++) {
      l.fallo();
    }
    expect(l.bloqueoRestante, isNotNull);
    ahora = ahora.add(const Duration(seconds: 31));
    expect(l.bloqueoRestante, isNull);
    expect(l.fallos, 0);
  });
}

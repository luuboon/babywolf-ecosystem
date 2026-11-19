// Práctica 13/14 · Fase 2 — Pruebas unitarias automatizadas (AUT-01 a AUT-03).
//
// Componente crítico elegido: el inicio de sesión y el registro (Validar,
// LimiteIntentos), más las reglas de comentarios y de notas guardadas.
// Cada prueba cubre una de las clases pedidas: entrada válida, vacía o nula,
// fuera de rango, resultado esperado y manejo de excepciones.
//
// Riesgo de la práctica anterior que previenen: D-06 (Post.fromJson / JSON roto
// sin controlar) y los límites de contraseña de 8 a 72 caracteres (bcrypt).

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_app/comentarios/comentarios_api.dart';
import 'package:phone_app/core/validacion.dart';
import 'package:phone_app/guardadas/guardadas.dart';
import 'package:phone_app/models/post.dart';

void main() {
  group('AUT-01 · Validar (inicio de sesión y registro)', () {
    test('AUT-01a entrada válida: correo, contraseña nueva y apodo se aceptan (null = válido)', () {
      expect(Validar.correo('abraham@uteq.edu.mx'), isNull);
      expect(Validar.contrasenaNueva('Clave1234'), isNull);
      expect(Validar.contrasena('cualquier cosa'), isNull);
      expect(Validar.apodo('luuboon_01'), isNull);
    });

    test('AUT-01b entrada vacía o nula: cada campo responde con su mensaje', () {
      expect(Validar.correo(null), 'Escribe tu correo');
      expect(Validar.correo('   '), 'Escribe tu correo');
      expect(Validar.contrasena(null), 'Escribe tu contraseña');
      expect(Validar.contrasenaNueva(''), 'Escribe una contraseña');
      expect(Validar.apodo(null), 'Escribe un nombre de usuario');
    });

    test('AUT-01c fuera de rango: contraseña nueva de 7 falla y de 8 pasa; de 72 pasa y de 73 falla', () {
      expect(Validar.contrasenaNueva('Abc1234'), contains('al menos 8'));
      expect(Validar.contrasenaNueva('Abc12345'), isNull);
      expect(Validar.contrasenaNueva('A1${'x' * 70}'), isNull); // 72
      expect(Validar.contrasenaNueva('A1${'x' * 71}'), 'Máximo 72 caracteres'); // 73
      expect(Validar.contrasena('x' * 73), 'Máximo 72 caracteres');
    });

    test('AUT-01d resultado esperado: la contraseña nueva exige letras y números y el correo, formato válido', () {
      expect(Validar.contrasenaNueva('soloLetras'), 'Combina letras y números');
      expect(Validar.contrasenaNueva('12345678'), 'Combina letras y números');
      expect(Validar.correo('sin-arroba.com'), contains('correo válido'));
      expect(Validar.correo('a@b'), contains('correo válido'));
      expect(Validar.apodo('ab'), 'Mínimo 3 caracteres');
      expect(Validar.apodo('con espacio'), contains('solo letras'));
    });

    test('AUT-01e la contraseña de inicio de sesión no se recorta: los espacios cuentan', () {
      expect(Validar.contrasena('   '), isNull);
    });
  });

  group('AUT-02 · reglas de comentarios y notas', () {
    test('AUT-02a comentario válido, vacío y en el límite de 280', () {
      expect(ReglasComentario.validar('Buen artículo'), isNull);
      expect(ReglasComentario.validar('   '), 'No se pueden enviar comentarios vacíos');
      expect(ReglasComentario.validar('x' * 280), isNull);
      expect(ReglasComentario.validar('x' * 281), 'Máximo 280 caracteres');
    });

    test('AUT-02b conteo por autor suma los comentarios de cada lector', () {
      Comentario c(String autor) => Comentario(id: '1', autorId: autor, autor: autor, texto: 't', hora: DateTime(2026));
      expect(ReglasComentario.conteo([c('a'), c('b'), c('a')]), {'a': 2, 'b': 1});
      expect(ReglasComentario.conteo([]), isEmpty);
    });

    test('AUT-02c nota guardada: 500 caracteres pasa y 501 no; la nota vacía es válida', () {
      expect(Guardada.validarNota(''), isNull);
      expect(Guardada.validarNota('n' * 500), isNull);
      expect(Guardada.validarNota('n' * 501), contains('500'));
    });
  });

  group('AUT-03 · LimiteIntentos y modelo Post', () {
    test('AUT-03a se bloquea tras 5 fallos y se libera al pasar la espera (reloj falso)', () {
      var ahora = DateTime(2026, 11, 18, 12);
      final l = LimiteIntentos(reloj: () => ahora);
      for (var i = 0; i < 4; i++) {
        l.fallo();
      }
      expect(l.bloqueoRestante, isNull, reason: '4 fallos todavía no bloquean');
      l.fallo();
      expect(l.bloqueoRestante, const Duration(seconds: 30));
      ahora = ahora.add(const Duration(seconds: 31));
      expect(l.bloqueoRestante, isNull);
      expect(l.fallos, 0);
    });

    test('AUT-03b un inicio de sesión correcto reinicia la cuenta de fallos', () {
      final l = LimiteIntentos();
      l.fallo();
      l.fallo();
      l.exito();
      expect(l.fallos, 0);
      expect(l.bloqueoRestante, isNull);
    });

    test('AUT-03c Post.fromJson con campos nulos o ausentes usa valores por omisión y no lanza excepción', () {
      final p = Post.fromJson({'id': null, 'title': null, 'created_at': 'no-es-fecha'});
      expect(p.id, '');
      expect(p.title, 'Sin título');
      expect(p.category, 'general');
      expect(p.createdAt, DateTime(2000));
    });

    test('AUT-03d Post.fromJson con tipos incorrectos lanza TypeError (excepción esperada y documentada)', () {
      expect(() => Post.fromJson({'id': 123}), throwsA(isA<TypeError>()));
    });
  });
}

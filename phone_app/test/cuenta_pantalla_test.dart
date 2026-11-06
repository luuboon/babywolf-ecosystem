// La pestaña Cuenta sin sesión debe mostrar el formulario (antes quedaba en
// blanco: una lista con scroll dentro de otra lista con scroll).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phone_app/core/sesion.dart';
import 'package:phone_app/cuenta/cuenta_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Cuenta sin sesión muestra el formulario y la mesa de ayuda', (tester) async {
    final sesion = Sesion(
      cliente: MockClient((_) async => http.Response('{}', 400)),
      almacen: AlmacenMemoria(),
    );
    await sesion.restaurar();

    await tester.pumpWidget(
      ChangeNotifierProvider<Sesion>.value(
        value: sesion,
        child: const MaterialApp(home: CuentaScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.text('Mesa de ayuda del equipo'), findsOneWidget);
  });
}

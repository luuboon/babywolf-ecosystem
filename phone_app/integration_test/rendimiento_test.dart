// Práctica 12 · Fase 2 — tiempos de FRAME reales de la app (build y raster) en el emulador, modo profile.
// Usa la app completa (consulta GET de lectura a producción). Los escenarios: carga inicial, desplazamiento
// de la lista, navegación entre pestañas y búsqueda. Cada uno produce average/90th/99th/worst de
// frame_build_time y frame_rasterizer_time, y "missed_frame_*_budget_count" (frames sobre 16.6 ms).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rendimiento de frames', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      final lista = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await tester.fling(lista, const Offset(0, -600), 1500);
        await tester.pumpAndSettle();
        await tester.fling(lista, const Offset(0, 600), 1500);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'desplazamiento_lista');

    await binding.watchPerformance(() async {
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.text('Guardadas').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cuenta').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Noticias').last);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'navegacion_pestanas');

    await binding.watchPerformance(() async {
      final buscar = find.byTooltip('Buscar noticias');
      if (buscar.evaluate().isNotEmpty) {
        await tester.tap(buscar);
        await tester.pumpAndSettle();
        final campo = find.byType(TextField);
        if (campo.evaluate().isNotEmpty) {
          for (final t in ['r', 're', 'ret', 'retr', 'retro']) {
            await tester.enterText(campo.first, t);
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpAndSettle();
        }
      }
    }, reportKey: 'busqueda_escribiendo');
  });
}

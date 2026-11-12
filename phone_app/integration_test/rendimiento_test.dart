// Práctica 12 · Fase 2 — tiempos de FRAME reales de la app (build y raster) en el emulador, modo profile.
// Usa la app completa (consulta GET de lectura a producción). No usa watchPerformance (requiere el servicio de VM y
// falla en este emulador); mide directamente los FrameTiming que entrega el motor y calcula los percentiles.
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_app/main.dart' as app;

/// Avanza el reloj en pasos de 50 ms durante [d] (pumpAndSettle nunca termina: hay animaciones continuas).
Future<void> _bombear(WidgetTester t, Duration d) async {
  for (var i = 0; i < d.inMilliseconds ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

double _pct(List<double> s, double p) => s.isEmpty ? 0 : s[((s.length - 1) * p).round()];

Future<void> _medir(WidgetTester t, String clave, Future<void> Function() accion) async {
  final tiempos = <FrameTiming>[];
  void cb(List<FrameTiming> l) => tiempos.addAll(l);
  SchedulerBinding.instance.addTimingsCallback(cb);
  final sw = Stopwatch()..start();
  await accion();
  await _bombear(t, const Duration(milliseconds: 1500)); // deja llegar los últimos lotes de FrameTiming
  SchedulerBinding.instance.removeTimingsCallback(cb);
  double ms(Duration d) => d.inMicroseconds / 1000;
  final build = tiempos.map((f) => ms(f.buildDuration)).toList()..sort();
  final raster = tiempos.map((f) => ms(f.rasterDuration)).toList()..sort();
  final total = tiempos.map((f) => ms(f.totalSpan)).toList()..sort();
  final lentos = total.where((x) => x > 16.67).length;
  final muyLentos = total.where((x) => x > 33.34).length;
  String f(List<double> s) => 'prom ${(s.isEmpty ? 0 : s.reduce((a, b) => a + b) / s.length).toStringAsFixed(2)}'
      ' · P90 ${_pct(s, .9).toStringAsFixed(2)} · P99 ${_pct(s, .99).toStringAsFixed(2)} · máx ${(s.isEmpty ? 0 : s.last).toStringAsFixed(2)}';
  // ignore: avoid_print
  print('FRAMES [$clave] frames=${tiempos.length} duración=${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s | '
      'build ms: ${f(build)} | raster ms: ${f(raster)} | total ms: ${f(total)} | '
      '>16.7ms: $lentos (${tiempos.isEmpty ? 0 : (100 * lentos / tiempos.length).toStringAsFixed(1)} %) · >33.3ms: $muyLentos');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rendimiento de frames', (tester) async {
    app.main();
    await _bombear(tester, const Duration(seconds: 6)); // carga inicial del feed

    await _medir(tester, 'reposo_5s', () => _bombear(tester, const Duration(seconds: 5)));

    await _medir(tester, 'desplazamiento_lista', () async {
      final lista = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await tester.fling(lista, const Offset(0, -600), 1500);
        await _bombear(tester, const Duration(milliseconds: 800));
        await tester.fling(lista, const Offset(0, 600), 1500);
        await _bombear(tester, const Duration(milliseconds: 800));
      }
    });

    await _medir(tester, 'navegacion_pestanas', () async {
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.text('Guardadas').last);
        await _bombear(tester, const Duration(milliseconds: 500));
        await tester.tap(find.text('Cuenta').last);
        await _bombear(tester, const Duration(milliseconds: 500));
        await tester.tap(find.text('Noticias').last);
        await _bombear(tester, const Duration(milliseconds: 500));
      }
    });

    await _medir(tester, 'busqueda_escribiendo', () async {
      final buscar = find.byTooltip('Buscar noticias');
      if (buscar.evaluate().isNotEmpty) {
        await tester.tap(buscar);
        await _bombear(tester, const Duration(milliseconds: 600));
        final campo = find.byType(TextField);
        if (campo.evaluate().isNotEmpty) {
          for (final t in ['r', 're', 'ret', 'retr', 'retro']) {
            await tester.enterText(campo.first, t);
            await _bombear(tester, const Duration(milliseconds: 150));
          }
          await _bombear(tester, const Duration(milliseconds: 600));
        }
      }
    });
  });
}

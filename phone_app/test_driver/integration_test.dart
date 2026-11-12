// Práctica 12 · Fase 2 — recoge el reporte de rendimiento que genera integration_test.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final salida = File('${Platform.environment['P12_SALIDA'] ?? 'build'}/rendimiento_frames.json');
        await salida.parent.create(recursive: true);
        await salida.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
      },
    );

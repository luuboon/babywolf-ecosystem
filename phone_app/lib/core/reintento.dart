// Práctica 12 · Fase 5 (reto) — reintento controlado con espera progresiva
// (exponential backoff + jitter) y generación de identificadores para que las
// ESCRITURAS sean idempotentes.
//
// Regla de uso:
//   · Lecturas (GET): se pueden reintentar siempre que el fallo sea transitorio.
//   · Escrituras: sólo si la operación lleva un identificador generado por el
//     cliente (ver [uuidV4]); así, si el servidor sí procesó la primera vez y la
//     respuesta se perdió, el reintento choca con la clave primaria (23505 / 409)
//     y se trata como "ya estaba guardado" en lugar de crear un duplicado.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Cuántas veces y con qué esperas se reintenta.
class PoliticaReintento {
  const PoliticaReintento({
    this.intentos = 3,
    this.base = const Duration(milliseconds: 500),
    this.tope = const Duration(seconds: 8),
    this.jitter = 0.25,
    this.presupuesto = const Duration(seconds: 20),
  });

  /// Intentos TOTALES (1 = sin reintentos).
  final int intentos;

  /// Espera antes del primer reintento; se duplica en cada uno.
  final Duration base;

  /// La espera nunca supera este valor.
  final Duration tope;

  /// Variación aleatoria ± (0.25 = ±25 %) para que muchos clientes no
  /// reintenten todos al mismo instante.
  final double jitter;

  /// Tiempo total máximo desde el primer intento: pasado esto ya no se reintenta.
  final Duration presupuesto;

  static const sinReintento = PoliticaReintento(intentos: 1);

  /// Espera antes del reintento número [reintento] (1 = el primero):
  /// base · 2^(reintento−1), limitada por [tope], con ±[jitter].
  Duration espera(int reintento, [Random? azar]) {
    final exp = base.inMilliseconds * pow(2, reintento - 1).toDouble();
    final limitada = min(exp, tope.inMilliseconds.toDouble());
    final factor = 1 + jitter * (2 * (azar ?? _azar).nextDouble() - 1);
    return Duration(milliseconds: (limitada * factor).round());
  }

  static final Random _azar = Random();
}

/// El servidor respondió, pero con un código que suele ser pasajero (5xx).
class RespuestaTransitoria implements Exception {
  const RespuestaTransitoria(this.respuesta);
  final http.Response respuesta;
}

/// 500, 502, 503 y 504 se consideran pasajeros; 4xx jamás se reintenta.
bool codigoTransitorio(int codigo) => codigo == 500 || codigo == 502 || codigo == 503 || codigo == 504;

/// Fallos que vale la pena reintentar: sin red, tiempo agotado, conexión
/// reiniciada y respuestas 5xx pasajeras.
bool esTransitorio(Object e) =>
    e is SocketException || e is TimeoutException || e is http.ClientException || e is RespuestaTransitoria;

Future<void> _dormir(Duration d) => Future<void>.delayed(d);

/// Ejecuta [operacion] hasta [PoliticaReintento.intentos] veces con espera
/// progresiva. [esperar] y [reloj] se inyectan en las pruebas para no esperar
/// de verdad. Si el fallo no es reintentable, o se agotan los intentos o el
/// presupuesto de tiempo, se relanza el último error.
Future<T> conReintento<T>(
  Future<T> Function(int intento) operacion, {
  PoliticaReintento politica = const PoliticaReintento(),
  bool Function(Object error) reintentable = esTransitorio,
  Future<void> Function(Duration) esperar = _dormir,
  DateTime Function() reloj = DateTime.now,
  Random? azar,
  void Function(int intento, Object error, Duration espera)? alReintentar,
}) async {
  final inicio = reloj();
  for (var n = 1;; n++) {
    try {
      return await operacion(n);
    } catch (e) {
      if (n >= politica.intentos || !reintentable(e)) rethrow;
      final espera = politica.espera(n, azar);
      if (reloj().difference(inicio) + espera >= politica.presupuesto) rethrow;
      alReintentar?.call(n, e, espera);
      await esperar(espera);
    }
  }
}

/// UUID versión 4 (aleatorio) sin dependencias externas. Sirve como clave de
/// idempotencia: el cliente lo genera UNA vez por acción del usuario y lo
/// reutiliza en todos los reintentos de esa acción.
String uuidV4([Random? azar]) {
  final r = azar ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versión 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

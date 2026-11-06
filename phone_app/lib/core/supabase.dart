// Proyecto de Supabase del blog BabyWolf: el mismo que usa la web.
//
// La llave "anon" es pública por diseño (la web la publica en su
// environment.prod.ts): sólo identifica el proyecto. Lo que protege los
// datos son las reglas RLS de la base (006 y 007 en babywolf-blog), que se
// aplican según el JWT del usuario que va en cada petición.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class Supabase {
  Supabase._();

  static const url = 'https://uwzynkvnqcupthvrtkry.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV3enlua3ZucWN1cHRodnJ0a3J5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMzE2NDcsImV4cCI6MjA4OTkwNzY0N30.H9cmX7cq5WFzOnpseB6Jay5-aSFh-nwc39uEQbCQwfg';

  static const timeout = Duration(seconds: 15);

  static Uri rest(String tabla, [Map<String, String>? query]) =>
      Uri.parse('$url/rest/v1/$tabla').replace(queryParameters: query);

  static Uri auth(String ruta, [Map<String, String>? query]) =>
      Uri.parse('$url/auth/v1/$ruta').replace(queryParameters: query);

  /// token null = petición sin sesión (sólo la llave pública).
  static Map<String, String> encabezados(String? token, {bool devolverFilas = false}) => {
        'apikey': anonKey,
        'Content-Type': 'application/json',
        if (devolverFilas) 'Prefer': 'return=representation',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Ejecuta una petición y traduce los fallos de red a [SinConexion].
  /// Nunca devuelve "éxito" si no hubo respuesta del servidor (Práctica 9,
  /// DB-09).
  static Future<http.Response> enviar(http.Client c, http.BaseRequest req) async {
    try {
      return await http.Response.fromStream(await c.send(req).timeout(timeout));
    } on SocketException {
      throw const SinConexion();
    } on TimeoutException {
      throw const SinConexion('El servidor no respondió a tiempo. No se guardó nada.');
    } on http.ClientException {
      throw const SinConexion();
    }
  }

  static http.Request peticion(String metodo, Uri uri, {String? token, Object? cuerpo, bool devolverFilas = false}) {
    final r = http.Request(metodo, uri)..headers.addAll(encabezados(token, devolverFilas: devolverFilas));
    if (cuerpo != null) r.body = jsonEncode(cuerpo);
    return r;
  }

  static dynamic json(http.Response r) {
    final t = utf8.decode(r.bodyBytes);
    if (t.isEmpty) return null;
    try {
      return jsonDecode(t);
    } on FormatException {
      return null;
    }
  }

  /// Mensaje de error legible de una respuesta de PostgREST o de Auth.
  static String detalle(http.Response r) {
    final j = json(r);
    if (j is Map) {
      final m = j['message'] ?? j['msg'] ?? j['error_description'] ?? j['error'];
      if (m is String && m.isNotEmpty) return m;
    }
    return 'El servidor respondió ${r.statusCode}.';
  }
}

/// No hubo respuesta del servidor: la operación NO se completó.
class SinConexion implements Exception {
  const SinConexion([this.mensaje = 'Sin conexión. No se guardó nada; inténtalo cuando vuelva la red.']);
  final String mensaje;

  @override
  String toString() => mensaje;
}

// Práctica 7 — Inicio de sesión del administrador con su cuenta del blog.
//
// Usa la API REST de Supabase Auth con la llave pública "anon" (la misma que
// ya publica el frontend web en environment.prod.ts: no es un secreto, sólo
// identifica el proyecto). La contraseña viaja por HTTPS a Supabase y no se
// guarda en el teléfono; lo que se guarda después es el token de la mesa.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'soporte_api.dart';

class SupabaseLogin {
  SupabaseLogin({http.Client? cliente}) : _c = cliente ?? http.Client();

  final http.Client _c;

  static const url = 'https://uwzynkvnqcupthvrtkry.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV3enlua3ZucWN1cHRodnJ0a3J5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMzE2NDcsImV4cCI6MjA4OTkwNzY0N30.H9cmX7cq5WFzOnpseB6Jay5-aSFh-nwc39uEQbCQwfg';

  /// Devuelve el access_token (JWT) del administrador.
  Future<String> entrar(String email, String contrasena) async {
    final http.Response r;
    try {
      r = await _c
          .post(
            Uri.parse('$url/auth/v1/token?grant_type=password'),
            headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': contrasena}),
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const SoporteException('Sin conexión con el servidor.', sinConexion: true);
    } on TimeoutException {
      throw const SoporteException('El servidor no respondió a tiempo.', sinConexion: true);
    } on http.ClientException {
      throw const SoporteException('Sin conexión con el servidor.', sinConexion: true);
    }
    if (r.statusCode == 200) {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['access_token'] is String) return j['access_token'] as String;
    }
    // Mensaje genérico (práctica 5): no se distingue correo inexistente de
    // contraseña incorrecta.
    throw SoporteException('Correo o contraseña incorrectos.', codigo: r.statusCode);
  }
}

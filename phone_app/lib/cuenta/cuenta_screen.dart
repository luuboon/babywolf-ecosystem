// Pestaña "Cuenta".
//
// Sin sesión: el formulario para entrar o crear cuenta (Práctica 5).
// Con sesión: quién eres (correo, UID y rol, Práctica 10), tus reportes
// (Prácticas 9 y 10), la mesa de ayuda del equipo (Práctica 7) y la
// actividad reciente de la cuenta sin datos sensibles (Práctica 5).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/log_seguro.dart';
import '../core/sesion.dart';
import '../core/widgets.dart';
import '../reportes/reportes_screen.dart';
import '../soporte/soporte_inicio_screen.dart';
import '../theme.dart';
import '../verificacion/verificacion_rls_screen.dart';
import 'entrar_screen.dart';

class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final cuenta = sesion.cuenta;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Cuenta', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: !sesion.listo
          ? const Center(child: CircularProgressIndicator(color: kNeon))
          : cuenta == null
              ? ListView(
                  children: [
                    const EntrarFormulario(),
                    const _Opciones(cuenta: null),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    _Perfil(cuenta: cuenta),
                    const SizedBox(height: 14),
                    _Opciones(cuenta: cuenta),
                    const SizedBox(height: 14),
                    const _Actividad(),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.read<Sesion>().salir();
                        if (context.mounted) avisar(context, 'Sesión cerrada');
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('CERRAR SESIÓN'),
                    ),
                  ],
                ),
    );
  }
}

class _Perfil extends StatelessWidget {
  const _Perfil({required this.cuenta});
  final Cuenta cuenta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSuperficie, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kNeon,
                child: Text(
                  cuenta.apodo.isEmpty ? '?' : cuenta.apodo[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cuenta.apodo, style: const TextStyle(color: kTexto, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(cuenta.correo, style: const TextStyle(color: kTenue)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cuenta.esAdmin ? kNeon : kFondo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cuenta.esAdmin ? 'ADMIN' : 'LECTOR',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // El UID es el identificador con el que la base decide qué puedes
          // ver (Práctica 10). Se muestra para la evidencia de pruebas.
          Row(
            children: [
              Expanded(
                child: Text(
                  'UID: ${cuenta.uid}',
                  style: const TextStyle(color: kTenue, fontSize: 11.5, fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: 'Copiar UID',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, color: kTenue, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cuenta.uid));
                  avisar(context, 'UID copiado');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Opciones extends StatelessWidget {
  const _Opciones({required this.cuenta});
  final Cuenta? cuenta;

  void _ir(BuildContext context, Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    return Container(
      margin: c == null ? const EdgeInsets.fromLTRB(16, 0, 16, 24) : EdgeInsets.zero,
      decoration: BoxDecoration(color: kSuperficie, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          if (c != null)
            _opcion(
              Icons.flag_outlined,
              c.esAdmin ? 'Reportes de lectores' : 'Mis reportes',
              c.esAdmin ? 'Atiende los problemas que reportan en las noticias' : 'Sigue los problemas que reportaste',
              () => _ir(context, const ReportesScreen()),
            ),
          _opcion(
            Icons.support_agent,
            'Mesa de ayuda del equipo',
            'Admin, agentes y usuarios invitados coordinan la atención',
            () => _ir(context, const SoporteInicioScreen()),
          ),
          if (kDebugMode)
            _opcion(
              Icons.verified_user_outlined,
              'Verificación de reglas (depuración)',
              'Intentos no autorizados SEG-04…SEG-10 contra la base',
              () => _ir(context, const VerificacionRlsScreen()),
            ),
        ],
      ),
    );
  }

  Widget _opcion(IconData icono, String titulo, String sub, VoidCallback onTap) => ListTile(
        onTap: onTap,
        leading: Icon(icono, color: kNeon),
        title: Text(titulo, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
        subtitle: Text(sub, style: const TextStyle(color: kTenue, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: kTenue),
      );
}

/// Últimos eventos de la cuenta en este teléfono. Nunca incluyen contraseñas
/// ni tokens, y el correo va enmascarado (LogSeguro).
class _Actividad extends StatelessWidget {
  const _Actividad();

  static const _nombres = {
    'inicio_sesion': 'Inicio de sesión',
    'inicio_fallido': 'Intento fallido',
    'validacion_rechazada': 'Datos inválidos',
    'cuenta_creada': 'Cuenta creada',
    'cierre_sesion': 'Cierre de sesión',
  };

  @override
  Widget build(BuildContext context) {
    final eventos = LogSeguro.eventos.take(6).toList();
    return Seccion(
      titulo: 'Actividad reciente en este teléfono',
      child: eventos.isEmpty
          ? const Text('Sin eventos.', style: TextStyle(color: kTenue))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in eventos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${horaCorta(e.hora)}  ${_legible(e.texto)}',
                      style: const TextStyle(color: kTenue, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
    );
  }

  static String _legible(String texto) {
    final partes = texto.split(' · ');
    final nombre = _nombres[partes.first] ?? partes.first;
    return partes.length > 1 ? '$nombre · ${partes.sublist(1).join(' · ')}' : nombre;
  }
}

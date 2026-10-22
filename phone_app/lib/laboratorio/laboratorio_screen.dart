// Menú de prácticas de laboratorio dentro de la app BabyWolf.
//
// Las prácticas no son apps nuevas: son módulos de la misma app del blog,
// que comparten su backend (Railway), su base de datos (Supabase) y su tema.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'p1_iot/iot_screen.dart';
import 'p3_consulta/consulta_web_screen.dart';
import 'p4_usuarios/usuarios_screen.dart';
import 'p5_acceso/acceso_seguro_screen.dart';
import 'p6_connect/mobile_connect_screen.dart';
import 'p7_soporte/soporte_inicio_screen.dart';

class _Practica {
  const _Practica(this.numero, this.titulo, this.descripcion, this.icono, this.pantalla);
  final String numero;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Widget Function()? pantalla;
}

final _practicas = <_Practica>[
  _Practica('1 y 2', 'Sensor IR · ESP32', 'Bluetooth clásico con el ESP32: objeto detectado, LED y botón.',
      Icons.sensors, () => const IotScreen()),
  _Practica('3', 'ConsultaWeb', 'Consumo de una URL preasignada del sitio BabyWolf.', Icons.cloud_download_outlined,
      () => const ConsultaWebScreen()),
  _Practica('4', 'Usuarios · SQLite', 'Registrar, consultar, modificar y eliminar en una base local.',
      Icons.storage_outlined, () => const UsuariosScreen()),
  _Practica('5', 'AccesoSeguro', 'Inicio de sesión con validación, errores genéricos y registro seguro.',
      Icons.lock_outline, () => const AccesoSeguroScreen()),
  _Practica('6', 'MobileConnect', 'Mensajes entre dos dispositivos con hora y contador.', Icons.forum_outlined,
      () => const MobileConnectScreen()),
  _Practica('7', 'Mesa de ayuda', 'Admin, agente y usuarios: reportes, mensajes y archivos con URLs preasignadas.',
      Icons.support_agent, () => const SoporteInicioScreen()),
  const _Practica('8', 'Pruebas de caja negra', 'Matriz de requisitos y evidencias en docs/practicas/practica8.',
      Icons.fact_check_outlined, null),
];

class LaboratorioScreen extends StatelessWidget {
  const LaboratorioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('Prácticas de laboratorio', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _practicas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = _practicas[i];
          return Material(
            color: kSuperficie,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: CircleAvatar(backgroundColor: kFondo, child: Icon(p.icono, color: kNeon)),
              title: Text('Práctica ${p.numero} · ${p.titulo}',
                  style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
              subtitle: Text(p.descripcion, style: const TextStyle(color: kTenue, fontSize: 12.5)),
              trailing: p.pantalla == null ? null : const Icon(Icons.chevron_right, color: kTenue),
              onTap: p.pantalla == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => p.pantalla!())),
            ),
          );
        },
      ),
    );
  }
}

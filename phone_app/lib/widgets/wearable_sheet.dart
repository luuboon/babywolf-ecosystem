// Panel del wearable: las métricas que llegan por GATT NOTIFY.
//
// Vive en un bottom sheet para no estorbar al feed de noticias, que es la
// pantalla principal de la app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble_client.dart';
import '../providers/activity_provider.dart';
import '../theme.dart';

class WearableSheet extends StatelessWidget {
  const WearableSheet({super.key});

  static void mostrar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSuperficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const WearableSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 38, height: 4, color: kTenue),
          ),
          const SizedBox(height: 18),
          _cabecera(a),
          const SizedBox(height: 20),
          if (a.alertaCritica) ...[
            _alerta(a.sinLeer),
            const SizedBox(height: 16),
          ],
          _metrica(
            icono: consolaDe(a.temaActivo ?? ''),
            etiqueta: 'Tema activo',
            valor: (a.temaActivo ?? '—').toUpperCase(),
          ),
          const SizedBox(height: 14),
          _metrica(
            icono: Icons.mark_email_unread_outlined,
            etiqueta: 'Noticias sin leer',
            valor: '${a.sinLeer}',
            resaltado: a.alertaCritica,
          ),
          const SizedBox(height: 14),
          _metrica(
            icono: Icons.timer_outlined,
            etiqueta: 'Minutos de lectura',
            valor: a.minutos.toStringAsFixed(1),
          ),
          const SizedBox(height: 18),
          Text(
            '${a.lecturas} notificaciones GATT recibidas',
            style: const TextStyle(color: kTenue, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _cabecera(ActivityProvider a) {
    final color = switch (a.estado) {
      EstadoBle.conectado => kVerde,
      EstadoBle.buscando => Colors.amber,
      EstadoBle.error => kNeon,
      EstadoBle.desconectado => kTenue,
    };

    return Row(
      children: [
        Container(width: 9, height: 9, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            a.textoEstado,
            style: const TextStyle(
              color: kTexto,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _alerta(int sinLeer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kNeonGlow,
        border: Border.all(color: kNeon, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kNeon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Backlog crítico: $sinLeer noticias sin leer',
              style: const TextStyle(
                color: kTexto,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrica({
    required IconData icono,
    required String etiqueta,
    required String valor,
    bool resaltado = false,
  }) {
    return Row(
      children: [
        Icon(icono, color: resaltado ? kNeon : kTenue, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            etiqueta,
            style: const TextStyle(color: kTenue, fontSize: 13),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: resaltado ? kNeon : kTexto,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// Tarjeta de resumen arriba del feed (Práctica 3).
//
// Muestra cuántas noticias tiene el blog y cuántas hay por tema. Los temas
// son botones: al tocar uno, el feed se filtra. Los datos llegan por la URL
// preasignada de ResumenServicio.

import 'package:flutter/material.dart';

import '../core/widgets.dart' show horaCorta;
import '../theme.dart';
import 'resumen_api.dart';

class ResumenTarjeta extends StatefulWidget {
  const ResumenTarjeta({
    super.key,
    required this.servicio,
    required this.categoria,
    required this.alElegir,
    this.recarga = 0,
  });

  final ResumenServicio servicio;
  final String? categoria;
  final ValueChanged<String?> alElegir;

  /// Cambia cuando el feed se recarga (deslizar hacia abajo).
  final int recarga;

  @override
  State<ResumenTarjeta> createState() => _ResumenTarjetaState();
}

class _ResumenTarjetaState extends State<ResumenTarjeta> {
  late Future<ResumenSitio> _futuro = widget.servicio.obtener();

  @override
  void didUpdateWidget(ResumenTarjeta old) {
    super.didUpdateWidget(old);
    if (old.recarga != widget.recarga) _consultar();
  }

  void _consultar() => setState(() => _futuro = widget.servicio.obtener());

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: kSuperficie, borderRadius: BorderRadius.circular(12)),
      child: FutureBuilder<ResumenSitio>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kNeon)),
                SizedBox(width: 12),
                Text('Consultando el resumen del blog…', style: TextStyle(color: kTenue, fontSize: 13)),
              ],
            );
          }
          if (snap.hasError) return _error(snap.error!);
          return _datos(snap.data!);
        },
      ),
    );
  }

  Widget _error(Object e) {
    final detalle = e is ConsultaException ? e.detalle : 'No fue posible obtener la información.';
    return Row(
      children: [
        const Icon(Icons.cloud_off, color: kTenue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No fue posible obtener el resumen. $detalle',
            style: const TextStyle(color: kTenue, fontSize: 12.5),
          ),
        ),
        TextButton(onPressed: _consultar, child: const Text('Reintentar')),
      ],
    );
  }

  Widget _datos(ResumenSitio r) {
    final cats = r.porCategoria.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final vence = widget.servicio.vence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${r.totalNoticias} noticias',
              style: const TextStyle(color: kTexto, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.descripcion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTenue, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip('Todas', null, r.totalNoticias),
            for (final c in cats) _chip(c.key, c.key, c.value),
          ],
        ),
        if (vence != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Consultado con enlace firmado · vence ${horaCorta(vence)}',
              style: const TextStyle(color: kTenue, fontSize: 10.5),
            ),
          ),
      ],
    );
  }

  Widget _chip(String texto, String? valor, int n) {
    final elegido = widget.categoria == valor;
    return ChoiceChip(
      selected: elegido,
      onSelected: (_) => widget.alElegir(valor),
      showCheckmark: false,
      avatar: valor == null ? null : Icon(consolaDe(valor), size: 14, color: elegido ? Colors.white : kNeon),
      label: Text('$texto · $n'),
      labelStyle: TextStyle(color: elegido ? Colors.white : kTexto, fontSize: 12, fontWeight: FontWeight.w700),
      selectedColor: kNeon,
      backgroundColor: kFondo,
      side: BorderSide(color: elegido ? kNeon : const Color(0x33FFFFFF)),
      visualDensity: VisualDensity.compact,
    );
  }
}

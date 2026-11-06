// "Mis reportes" (lector) o "Reportes de lectores" (admin). Prácticas 9 y 10.
//
// La lista se vuelve a consultar cada 5 s mientras está abierta, así lo que
// otro dispositivo crea o cambia aparece sin tocar nada (DB-03, DB-05, DB-06).
// También se puede deslizar hacia abajo para consultar en el momento.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../core/supabase.dart';
import '../core/widgets.dart';
import '../theme.dart';
import 'reporte_screen.dart';
import 'reportes_api.dart';

const kIntervaloSincronia = Duration(seconds: 5);

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key, this.api});

  final ReportesApi? api;

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late final ReportesApi _api = widget.api ?? ReportesApi();
  Timer? _timer;
  List<Reporte>? _lista;
  String? _filtro;
  String? _error;
  DateTime? _ultima;

  @override
  void initState() {
    super.initState();
    _consultar();
    _timer = Timer.periodic(kIntervaloSincronia, (_) => _consultar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    final sesion = context.read<Sesion>();
    try {
      final lista = await _api.listar(await sesion.token());
      if (!mounted) return;
      setState(() {
        _lista = lista;
        _error = null;
        _ultima = DateTime.now();
      });
    } on SinConexion {
      if (mounted) setState(() => _error = 'Sin conexión: mostrando lo último que se consultó.');
    } on Exception catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _abrir(Reporte r) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReporteScreen(inicial: r, api: _api)));
    _consultar();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<Sesion>().esAdmin;
    final todos = _lista;
    final lista = todos?.where((r) => _filtro == null || r.estado == _filtro).toList();

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: Text(
          admin ? 'Reportes de lectores' : 'Mis reportes',
          style: const TextStyle(color: kTexto, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _consultar,
        color: kNeon,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              admin
                  ? 'Ves los reportes de todos los lectores porque tu cuenta es admin.'
                  : 'Sólo tú y el equipo de BabyWolf ven tus reportes.',
              style: const TextStyle(color: kTenue, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _chip('Todos', null, todos?.length),
                for (final e in kEstados.entries)
                  _chip(e.value, e.key, todos?.where((r) => r.estado == e.key).length),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(_error == null ? Icons.sync : Icons.sync_problem, size: 14, color: _error == null ? kVerde : kNeonTexto),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error ?? (_ultima == null ? 'Consultando…' : 'Sincronizado a las ${horaCorta(_ultima!)} · se actualiza cada 5 s'),
                    style: TextStyle(color: _error == null ? kTenue : kNeonTexto, fontSize: 11.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lista == null && _error == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: kNeon)))
            else if (lista == null || lista.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  admin
                      ? 'No hay reportes con este filtro.'
                      : 'No tienes reportes. Si ves un problema en una noticia, usa la bandera de arriba en su detalle.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kTenue, height: 1.4),
                ),
              )
            else
              for (final r in lista) _tarjeta(r),
          ],
        ),
      ),
    );
  }

  Widget _chip(String texto, String? valor, int? n) => ChoiceChip(
        label: Text(n == null ? texto : '$texto · $n'),
        selected: _filtro == valor,
        onSelected: (_) => setState(() => _filtro = valor),
        selectedColor: kNeon,
        showCheckmark: false,
        labelStyle: TextStyle(color: _filtro == valor ? Colors.white : kTexto, fontSize: 12),
        backgroundColor: kSuperficie,
        visualDensity: VisualDensity.compact,
      );

  Widget _tarjeta(Reporte r) {
    return Card(
      color: kSuperficie,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _abrir(r),
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        title: Text(r.titulo, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.postTitulo.isNotEmpty)
                Text(r.postTitulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTenue, fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                EtiquetaEstado(r.estado),
                EtiquetaPrioridad(r.prioridad),
                Text('v${r.version}', style: const TextStyle(color: kTenue, fontSize: 11)),
              ]),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: kTenue),
      ),
    );
  }
}

class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'cerrada' => kVerde,
      'en_proceso' => Colors.amber,
      _ => kNeonTexto,
    };
    return _Etiqueta(kEstados[estado] ?? estado, color);
  }
}

class EtiquetaPrioridad extends StatelessWidget {
  const EtiquetaPrioridad(this.prioridad, {super.key});
  final String prioridad;

  @override
  Widget build(BuildContext context) {
    final color = switch (prioridad) {
      'critica' => kNeon,
      'alta' => Colors.orangeAccent,
      'baja' => kTenue,
      _ => Colors.lightBlueAccent,
    };
    return _Etiqueta('Prioridad ${kPrioridades[prioridad] ?? prioridad}', color);
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, this.color);
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

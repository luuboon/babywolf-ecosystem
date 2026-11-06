// "Reportar un problema" desde el detalle de una noticia (Práctica 9, DB-02).
//
// Sólo se confirma cuando la base devuelve el reporte creado. Si no hay red,
// la hoja se queda abierta con lo escrito y dice que NO se guardó (DB-09).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../core/supabase.dart';
import '../core/widgets.dart';
import '../cuenta/entrar_screen.dart';
import '../models/post.dart';
import '../theme.dart';
import 'reportes_api.dart';

class ReportarSheet extends StatefulWidget {
  const ReportarSheet({super.key, required this.post, this.api});

  final Post post;
  final ReportesApi? api;

  static Future<void> mostrar(BuildContext context, Post post) async {
    if (!context.read<Sesion>().activa) {
      await EntrarScreen.abrir(context);
      if (!context.mounted || !context.read<Sesion>().activa) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kFondo,
      builder: (_) => ReportarSheet(post: post),
    );
  }

  @override
  State<ReportarSheet> createState() => _ReportarSheetState();
}

class _ReportarSheetState extends State<ReportarSheet> {
  late final ReportesApi _api = widget.api ?? ReportesApi();
  final _descripcion = TextEditingController();
  String? _motivo;
  String _prioridad = 'media';
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final invalido = ReglasReporte.titulo(_motivo ?? '') ?? ReglasReporte.descripcion(_descripcion.text);
    if (invalido != null) {
      setState(() => _error = invalido);
      return;
    }
    final sesion = context.read<Sesion>();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final r = await _api.crear(
        await sesion.token(),
        titulo: _motivo!,
        descripcion: _descripcion.text,
        prioridad: _prioridad,
        post: widget.post,
      );
      if (!mounted) return;
      avisar(context, 'Reporte enviado (${r.estadoTexto}). Síguelo en Cuenta → Mis reportes.');
      Navigator.of(context).pop();
    } on SinConexion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on AuthFallo catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on ReporteFallo catch (e) {
      if (mounted) setState(() => _error = 'No se envió el reporte. ${e.mensaje}');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reportar un problema', style: TextStyle(color: kTexto, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.post.title, style: const TextStyle(color: kTenue)),
            const SizedBox(height: 16),
            const Text('¿Qué pasa?', style: TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in kMotivos)
                  ChoiceChip(
                    label: Text(m),
                    selected: _motivo == m,
                    onSelected: (_) => setState(() => _motivo = m),
                    selectedColor: kNeon,
                    labelStyle: TextStyle(color: _motivo == m ? Colors.white : kTexto),
                    backgroundColor: kSuperficie,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 5,
              maxLength: ReglasReporte.maxDescripcion,
              style: const TextStyle(color: kTexto),
              decoration: campo('Detalles (opcional)', ayuda: 'Ej. la portada no carga en el teléfono'),
            ),
            const Text('¿Qué tan grave es?', style: TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final p in kPrioridades.entries) ButtonSegment(value: p.key, label: Text(p.value)),
              ],
              selected: {_prioridad},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _prioridad = s.first),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!, style: const TextStyle(color: kNeonTexto, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: BotonPrincipal(
                texto: _enviando ? 'ENVIANDO…' : 'ENVIAR REPORTE',
                icono: Icons.flag_outlined,
                onPressed: _enviando ? null : _enviar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

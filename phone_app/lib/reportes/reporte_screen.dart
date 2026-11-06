// Detalle de un reporte: ver, editar y guardar (Prácticas 9 y 10).
//
// Quién cambia qué:
//   - El lector dueño: la descripción y la prioridad. Puede borrar su
//     reporte mientras siga "Pendiente".
//   - El admin: el estado (Pendiente → En proceso → Resuelto) y la prioridad.
// La base lo respalda con RLS: aunque se modificara la app, un lector no
// podría tocar reportes ajenos.
//
// Editar y guardar están separados. Mientras el reporte está abierto se
// consulta cada 5 s; si otro dispositivo lo cambia, aquí se ve. Si tú tienes
// cambios sin guardar y otro guardó antes, al guardar la base lo detecta por
// la versión (ConflictoVersion): no se pisa nada, se cargan los valores
// nuevos y tus cambios siguen en pantalla para volver a guardarlos.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../core/supabase.dart';
import '../core/widgets.dart';
import '../theme.dart';
import 'reportes_api.dart';
import 'reportes_screen.dart' show EtiquetaEstado, EtiquetaPrioridad, kIntervaloSincronia;

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key, required this.inicial, this.api});

  final Reporte inicial;
  final ReportesApi? api;

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  late final ReportesApi _api = widget.api ?? ReportesApi();

  /// Última versión leída de la base: los cambios se calculan contra esta.
  late Reporte _base = widget.inicial;

  late String _estado = _base.estado;
  late String _prioridad = _base.prioridad;
  late final _descripcion = TextEditingController(text: _base.descripcion);

  /// Versión más nueva vista en la base mientras hay cambios sin guardar.
  Reporte? _remoto;
  Timer? _timer;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descripcion.addListener(() => setState(() {}));
    _timer = Timer.periodic(kIntervaloSincronia, (_) => _vigilar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _descripcion.dispose();
    super.dispose();
  }

  Map<String, Object> get _cambios => {
        if (_estado != _base.estado) 'estado': _estado,
        if (_prioridad != _base.prioridad) 'prioridad': _prioridad,
        if (_descripcion.text.trim() != _base.descripcion) 'descripcion': _descripcion.text.trim(),
      };

  /// Pone en pantalla [r] sin perder lo que el usuario cambió y no ha guardado.
  void _adoptar(Reporte r) {
    final pendientes = _cambios;
    _base = r;
    _remoto = null;
    if (!pendientes.containsKey('estado')) _estado = r.estado;
    if (!pendientes.containsKey('prioridad')) _prioridad = r.prioridad;
    if (!pendientes.containsKey('descripcion')) _descripcion.text = r.descripcion;
  }

  Future<void> _vigilar() async {
    if (_guardando) return;
    try {
      final r = await _api.leer(await context.read<Sesion>().token(), _base.id);
      if (!mounted || r == null || r.version <= (_remoto ?? _base).version) return;
      setState(() {
        if (_cambios.isEmpty) {
          _adoptar(r); // nada pendiente: se actualiza solo
        } else {
          _remoto = r; // hay cambios tuyos: sólo se avisa
        }
      });
    } catch (_) {
      // La vigilancia es silenciosa; los errores se muestran al guardar.
    }
  }

  Future<void> _guardar() async {
    final sesion = context.read<Sesion>();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final nuevo = await _api.guardar(await sesion.token(), _base, _cambios);
      if (!mounted) return;
      setState(() {
        _base = nuevo;
        _remoto = null;
        _estado = nuevo.estado;
        _prioridad = nuevo.prioridad;
        _descripcion.text = nuevo.descripcion;
      });
      avisar(context, 'Guardado en la base (versión ${nuevo.version})');
    } on ConflictoVersion catch (c) {
      if (!mounted) return;
      final cambio = _base.diferencias(c.actual);
      setState(() => _adoptar(c.actual));
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: kSuperficie,
          title: const Text('Otro dispositivo guardó antes', style: TextStyle(color: kTexto)),
          content: Text(
            'Mientras editabas, alguien guardó la versión ${c.actual.version}'
            '${cambio.isEmpty ? '' : ' (cambió ${cambio.join(', ')})'}.\n\n'
            'No se sobrescribió nada. Ya ves sus valores, y tus cambios siguen en pantalla sin guardar: '
            'revísalos y vuelve a guardar si siguen siendo correctos.',
            style: const TextStyle(color: kTenue, height: 1.4),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Entendido'))],
        ),
      );
    } on SinConexion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'No se guardó. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Borrar reporte', style: TextStyle(color: kTexto)),
        content: const Text('¿Retirar este reporte? No se puede deshacer.', style: TextStyle(color: kTenue)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final sesion = context.read<Sesion>();
    try {
      final borrado = await _api.eliminar(await sesion.token(), _base.id);
      if (!mounted) return;
      if (borrado) {
        avisar(context, 'Reporte borrado');
        Navigator.of(context).pop();
      } else {
        avisar(context, 'La base no permitió borrarlo.', error: true);
      }
    } on Exception catch (e) {
      if (mounted) avisar(context, 'No se borró. $e', error: true);
    }
  }

  String _quien(String? uid, Cuenta? yo) {
    if (uid == null) return '';
    if (uid == yo?.uid) return ' por ti';
    if (uid == _base.creadoPor) return ' por el lector';
    return ' por el equipo de BabyWolf';
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final yo = sesion.cuenta;
    final dueno = yo?.uid == _base.creadoPor;
    final admin = sesion.esAdmin;
    final pendientes = _cambios;
    final remoto = _remoto;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('Reporte', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
        actions: [
          if (dueno && _base.estado == 'abierta')
            IconButton(tooltip: 'Borrar reporte', onPressed: _borrar, icon: const Icon(Icons.delete_outline, color: kTexto)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (remoto != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber),
              ),
              child: Text(
                'Este reporte cambió en otro dispositivo (versión ${remoto.version}: '
                '${_base.diferencias(remoto).join(', ')}). Tienes cambios sin guardar; al guardar se te pedirá revisarlos.',
                style: const TextStyle(color: Colors.amber, height: 1.4),
              ),
            ),
          Text(_base.titulo, style: const TextStyle(color: kTexto, fontSize: 22, fontWeight: FontWeight.w800)),
          if (_base.postTitulo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Noticia: ${_base.postTitulo}', style: const TextStyle(color: kTenue)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [EtiquetaEstado(_base.estado), EtiquetaPrioridad(_base.prioridad)]),
          const SizedBox(height: 6),
          Text(
            'Versión ${_base.version}'
            '${_base.actualizado == null ? '' : ' · último cambio ${horaCorta(_base.actualizado!)}${_quien(_base.actualizadoPor, yo)}'}',
            style: const TextStyle(color: kTenue, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (admin) ...[
            const _Rotulo('Estado (lo cambia el equipo)'),
            SegmentedButton<String>(
              segments: [for (final e in kEstados.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_estado},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _estado = s.first),
            ),
            const SizedBox(height: 18),
          ],
          const _Rotulo('Prioridad'),
          SegmentedButton<String>(
            segments: [for (final p in kPrioridades.entries) ButtonSegment(value: p.key, label: Text(p.value))],
            selected: {_prioridad},
            showSelectedIcon: false,
            onSelectionChanged: dueno || admin ? (s) => setState(() => _prioridad = s.first) : null,
          ),
          const SizedBox(height: 18),
          const _Rotulo('Descripción'),
          TextField(
            controller: _descripcion,
            enabled: dueno,
            minLines: 2,
            maxLines: 6,
            maxLength: ReglasReporte.maxDescripcion,
            style: const TextStyle(color: kTexto),
            decoration: campo(dueno ? 'Detalles del problema' : 'Sólo el lector que reportó la edita'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: kNeonTexto, fontWeight: FontWeight.w600)),
            ),
          BotonPrincipal(
            texto: _guardando
                ? 'GUARDANDO…'
                : pendientes.isEmpty
                    ? 'SIN CAMBIOS'
                    : 'GUARDAR ${pendientes.length} ${pendientes.length == 1 ? 'CAMBIO' : 'CAMBIOS'}',
            icono: Icons.save_outlined,
            onPressed: _guardando || pendientes.isEmpty ? null : _guardar,
          ),
          if (pendientes.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _estado = _base.estado;
                _prioridad = _base.prioridad;
                _descripcion.text = _base.descripcion;
              }),
              child: const Text('Descartar mis cambios'),
            ),
        ],
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto.toUpperCase(),
            style: const TextStyle(color: kNeonTexto, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      );
}

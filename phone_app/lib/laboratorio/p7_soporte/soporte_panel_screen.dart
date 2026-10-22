// Práctica 7 — Panel de la mesa de ayuda: Reportes · Mensajes · Dispositivos.
//
// Tiempo real sólo para administrador y agente: cada 3 s consultan
// /monitor y recargan si algo cambió. Los usuarios recargan a mano.
// Todos mandan un latido cada 10 s; sin latido por 30 s cuentan como
// desconectados y entra en juego el intercambio de roles.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'almacen_soporte.dart';
import 'modelos.dart';
import 'soporte_api.dart';
import 'soporte_inicio_screen.dart';

class SoportePanelScreen extends StatefulWidget {
  const SoportePanelScreen({super.key, required this.api, required this.almacen, required this.yo});

  final SoporteApi api;
  final AlmacenSoporte almacen;
  final Participante yo;

  @override
  State<SoportePanelScreen> createState() => _SoportePanelScreenState();
}

class _SoportePanelScreenState extends State<SoportePanelScreen> {
  SoporteApi get _api => widget.api;

  late Participante _yo = widget.yo;
  String _rol = kRolUsuario; // rol efectivo
  List<Participante> _participantes = [];
  List<Reporte> _reportes = [];
  final List<MensajeSoporte> _mensajes = [];
  List<ConteoEmisor> _conteo = [];
  List<Pendiente> _pendientes = [];

  bool _enLinea = true;
  bool _conectado = true; // el usuario puede "desconectarse" para probar el cambio de roles
  int _ultimoMensaje = 0;
  int _ocultarHasta = 0; // limpieza local del historial (roles sin permiso de borrar)
  DateTime? _firmaReportes;
  String _filtroEstado = '';
  String? _para; // destinatario del mensaje (null = todos)
  final _busqueda = TextEditingController();
  final _consultaId = TextEditingController();
  final _texto = TextEditingController();
  bool _enviando = false;
  bool _sincronizando = false;
  bool _cerrando = false;

  Timer? _timerLatido;
  Timer? _timerMonitor;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  @override
  void dispose() {
    _timerLatido?.cancel();
    _timerMonitor?.cancel();
    _busqueda.dispose();
    _consultaId.dispose();
    _texto.dispose();
    super.dispose();
  }

  // ── ciclo de conexión ───────────────────────────────────────

  Future<void> _arrancar() async {
    await _latido();
    await _recargarTodo();
    _timerLatido = Timer.periodic(const Duration(seconds: 10), (_) => _latido());
    _timerMonitor = Timer.periodic(const Duration(seconds: 3), (_) => _monitor());
  }

  /// Manejo común de errores: 401 = sesión vencida o expulsado.
  Future<bool> _intentar(Future<void> Function() accion, {bool silencioso = false}) async {
    try {
      await accion();
      if (!_enLinea && mounted) setState(() => _enLinea = true);
      return true;
    } on SoporteException catch (e) {
      if (!mounted) return false;
      if (e.codigo == 401) {
        await _cerrarSesion(avisoExpulsion: true);
        return false;
      }
      if (e.sinConexion) {
        setState(() => _enLinea = false);
      }
      if (!silencioso) avisar(context, e.mensaje, error: true);
      return false;
    }
  }

  Future<void> _latido() async {
    if (!_conectado) return;
    final ok = await _intentar(() async {
      final est = await _api.latido();
      if (!mounted) return;
      setState(() {
        _yo = est.yo;
        _rol = est.rolEfectivo;
        _participantes = est.participantes;
      });
    }, silencioso: true);
    if (ok) await _sincronizarPendientes();
  }

  /// Comprobación en tiempo real (admin y agente).
  Future<void> _monitor() async {
    if (!_conectado || !puedeMonitorear(_rol)) return;
    await _intentar(() async {
      final m = await _api.monitor(_yo);
      if (!mounted) return;
      final cambioReportes = m.reportes != _firmaReportes;
      final cambioMensajes = m.ultimoMensaje != _ultimoMensaje;
      setState(() {
        _rol = m.estado.rolEfectivo;
        _participantes = m.estado.participantes;
      });
      if (cambioReportes) await _cargarReportes(silencioso: true);
      if (cambioMensajes) await _cargarMensajes(avisarNuevos: true);
      _firmaReportes = m.reportes;
    }, silencioso: true);
  }

  Future<void> _recargarTodo() async {
    await _cargarReportes();
    await _cargarMensajes();
    final p = await widget.almacen.pendientes();
    if (mounted) setState(() => _pendientes = p);
  }

  Future<void> _cargarReportes({bool silencioso = false}) => _intentar(() async {
        final r = await _api.reportes(estado: _filtroEstado, texto: _busqueda.text);
        if (mounted) setState(() => _reportes = r);
      }, silencioso: silencioso);

  Future<void> _cargarMensajes({bool avisarNuevos = false}) => _intentar(() async {
        final r = await _api.mensajes();
        if (!mounted) return;
        final nuevos = r.mensajes.where((m) => m.id > _ultimoMensaje && m.emisorId != _yo.id).toList();
        setState(() {
          // Si el admin limpió el historial, la lista del servidor viene vacía.
          _mensajes
            ..clear()
            ..addAll(r.mensajes);
          _conteo = r.conteo;
          _ultimoMensaje = r.mensajes.isEmpty ? 0 : r.mensajes.last.id;
        });
        if (avisarNuevos && nuevos.isNotEmpty) {
          avisar(context, 'Nuevo mensaje de ${nuevos.last.emisorNombre}');
        }
      }, silencioso: true);

  /// TC07: reenvía lo que quedó pendiente por falta de conexión.
  Future<void> _sincronizarPendientes() async {
    if (_sincronizando) return; // evita reenviar dos veces lo mismo
    _sincronizando = true;
    try {
      await _sincronizar();
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _sincronizar() async {
    final lista = await widget.almacen.pendientes();
    if (lista.isEmpty) {
      if (_pendientes.isNotEmpty && mounted) setState(() => _pendientes = []);
      return;
    }
    var enviados = 0;
    for (final p in lista) {
      try {
        switch (p.tipo) {
          case 'crear_reporte':
            await _api.crearReporte(p.datos);
          case 'actualizar_reporte':
            final datos = Map<String, dynamic>.of(p.datos);
            final id = datos.remove('id') as String;
            await _api.actualizarReporte(id, datos);
          default:
            await _api.enviar(p.datos);
        }
        enviados++;
        await widget.almacen.quitarPendiente(p.id);
      } on SoporteException catch (e) {
        if (e.sinConexion) break; // sigue sin red: se reintenta en el próximo latido
        // El servidor lo rechazó (p. ej. ID repetido): no se reintenta para siempre.
        await widget.almacen.quitarPendiente(p.id);
        if (mounted) avisar(context, 'Pendiente rechazado: ${e.mensaje}', error: true);
      }
    }
    final restantes = await widget.almacen.pendientes();
    if (!mounted) return;
    setState(() => _pendientes = restantes);
    if (enviados > 0) {
      avisar(context, 'Se sincronizaron $enviados operaciones pendientes');
      await _cargarReportes(silencioso: true);
      await _cargarMensajes();
    }
  }

  Future<void> _guardarPendiente(String tipo, Map<String, dynamic> datos) async {
    await widget.almacen.agregarPendiente(tipo, datos);
    final p = await widget.almacen.pendientes();
    if (!mounted) return;
    setState(() {
      _pendientes = p;
      _enLinea = false;
    });
    avisar(context, 'Sin conexión: la operación quedó pendiente y se enviará al volver la red.', error: true);
  }

  Future<void> _cambiarConexion(bool v) async {
    if (!v) {
      await _intentar(() => _api.salir(), silencioso: true);
      setState(() => _conectado = false);
      if (mounted) avisar(context, 'Te desconectaste de la mesa');
    } else {
      setState(() => _conectado = true);
      await _latido();
      await _recargarTodo();
    }
  }

  Future<void> _cerrarSesion({bool avisoExpulsion = false}) async {
    if (_cerrando) return;
    _cerrando = true;
    _timerLatido?.cancel();
    _timerMonitor?.cancel();
    if (!avisoExpulsion) {
      try {
        await _api.salir();
      } on SoporteException {
        // Sin red: igual se borra la sesión local.
      }
    }
    await widget.almacen.borrarSesion();
    _api.token = null;
    if (!mounted) return;
    if (avisoExpulsion) avisar(context, 'Tu sesión terminó. Vuelve a unirte.', error: true);
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const SoporteInicioScreen()));
  }

  String _nombreDe(String? id) {
    if (id == null) return 'Sin asignar';
    for (final p in _participantes) {
      if (p.id == id) return p.nombre;
    }
    return id == _yo.id ? _yo.nombre : 'Participante';
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: kTexto),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_yo.nombre, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w800, fontSize: 17)),
              Text(etiquetaRol(_rol), style: const TextStyle(color: kNeonTexto, fontSize: 12)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.circle, size: 10, color: _conectado && _enLinea ? kVerde : kNeon),
            ),
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh, color: kTexto),
              onPressed: _recargarTodo,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: kNeon,
            labelColor: kTexto,
            unselectedLabelColor: kTenue,
            tabs: [Tab(text: 'Reportes'), Tab(text: 'Mensajes'), Tab(text: 'Dispositivos')],
          ),
        ),
        body: Column(
          children: [
            if (_pendientes.isNotEmpty) _bannerPendientes(),
            if (!puedeMonitorear(_rol))
              Container(
                width: double.infinity,
                color: kSuperficie,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: const Text(
                  'Vista de usuario: sin actualización en tiempo real. Usa ⟳ para actualizar.',
                  style: TextStyle(color: kTenue, fontSize: 12),
                ),
              ),
            Expanded(
              child: TabBarView(children: [_tabReportes(), _tabMensajes(), _tabDispositivos()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerPendientes() {
    return Material(
      color: Colors.amber.shade800,
      child: InkWell(
        onTap: _latido,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_pendientes.length} pendiente(s) sin enviar: ${_pendientes.first.descripcion}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const Text('REINTENTAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reportes ─────────────────────────────────────────────────

  Widget _tabReportes() {
    return Scaffold(
      backgroundColor: kFondo,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kNeon,
        foregroundColor: Colors.white,
        onPressed: _nuevoReporte,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reporte'),
      ),
      body: RefreshIndicator(
        color: kNeon,
        onRefresh: () => _cargarReportes(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _consultaId,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: kTexto),
                    decoration: campo('Consultar por ID', ayuda: 'Ej. REP001'),
                    onSubmitted: (_) => _consultarPorId(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: kNeon),
                  onPressed: _consultarPorId,
                  icon: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _busqueda,
              style: const TextStyle(color: kTexto),
              decoration: campo('Buscar por equipo o descripción'),
              onSubmitted: (_) => _cargarReportes(),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in ['', ...kEstados])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.isEmpty ? 'Todos' : e),
                        selected: _filtroEstado == e,
                        onSelected: (_) {
                          setState(() => _filtroEstado = e);
                          _cargarReportes();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_reportes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text('No hay reportes activos.', textAlign: TextAlign.center, style: TextStyle(color: kTenue)),
              ),
            for (final r in _reportes) _tarjetaReporte(r),
          ],
        ),
      ),
    );
  }

  Color _colorPrioridad(String p) => switch (p) {
        'Alta' => kNeon,
        'Media' => Colors.amber,
        _ => kVerde,
      };

  Widget _tarjetaReporte(Reporte r) {
    return Card(
      color: kSuperficie,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _detalle(r),
        title: Row(
          children: [
            Text(r.id, style: const TextStyle(color: kNeonTexto, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r.equipo,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _colorPrioridad(r.prioridad).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(r.prioridad, style: TextStyle(color: _colorPrioridad(r.prioridad), fontSize: 12)),
            ),
          ],
        ),
        subtitle: Text(
          '${kTipos[r.tipo] ?? r.tipo} · ${r.estado} · ${_nombreDe(r.agenteId)}'
          '${r.directoAdmin ? ' · directo al admin' : ''}',
          style: const TextStyle(color: kTenue, fontSize: 12.5),
        ),
      ),
    );
  }

  Future<void> _consultarPorId() async {
    final id = _consultaId.text.trim().toUpperCase();
    if (id.isEmpty) {
      avisar(context, 'Escribe un ID, por ejemplo REP001', error: true);
      return;
    }
    // TC06: un ID inexistente se informa sin bloquear la app.
    await _intentar(() async {
      final r = await _api.reporte(id);
      if (mounted) _detalle(r);
    });
  }

  Future<void> _nuevoReporte() async {
    final datos = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSuperficie,
      builder: (_) => const _FormReporte(),
    );
    if (datos == null) return;
    try {
      final r = await _api.crearReporte(datos);
      if (!mounted) return;
      avisar(context, 'Reporte ${r.id} guardado');
      await _cargarReportes();
    } on SoporteException catch (e) {
      if (!mounted) return;
      if (e.sinConexion) {
        await _guardarPendiente('crear_reporte', datos); // TC07
      } else {
        // TC02 / TC03: validación o ID repetido.
        final detalle = e.campos.isEmpty ? '' : ' (${e.campos.values.join(', ')})';
        avisar(context, '${e.mensaje}$detalle', error: true);
      }
    }
  }

  Future<void> _actualizar(Reporte r, Map<String, dynamic> cambios) async {
    try {
      final nuevo = await _api.actualizarReporte(r.id, cambios);
      if (!mounted) return;
      avisar(context, '${nuevo.id} actualizado');
      await _cargarReportes();
    } on SoporteException catch (e) {
      if (!mounted) return;
      if (e.sinConexion) {
        await _guardarPendiente('actualizar_reporte', {'id': r.id, ...cambios});
      } else {
        avisar(context, e.mensaje, error: true);
      }
    }
  }

  void _detalle(Reporte r) {
    final esAdmin = puedeAdministrar(_rol);
    final esSuAgente = _rol == kRolAgente && r.agenteId == _yo.id;
    final puedeCambiar = esAdmin || esSuAgente;
    final agentes = _participantes.where((p) => p.rol != kRolUsuario).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSuperficie,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.id} · ${r.equipo}',
                style: const TextStyle(color: kTexto, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(r.descripcion, style: const TextStyle(color: kTexto, height: 1.45)),
            const SizedBox(height: 10),
            Text(
              'Tipo: ${kTipos[r.tipo] ?? r.tipo}\nSolicitó: ${_nombreDe(r.solicitanteId)}\n'
              'Atiende: ${_nombreDe(r.agenteId)}\nEstado: ${r.estado}',
              style: const TextStyle(color: kTenue, height: 1.5),
            ),
            const SizedBox(height: 14),
            if (puedeCambiar) ...[
              Row(
                children: [
                  const SizedBox(width: 80, child: Text('Prioridad', style: TextStyle(color: kTenue))),
                  for (final p in kPrioridades)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p),
                        selected: r.prioridad == p,
                        onSelected: (_) {
                          Navigator.pop(c);
                          if (p != r.prioridad) _actualizar(r, {'prioridad': p});
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in kEstados)
                    ChoiceChip(
                      label: Text(e),
                      selected: r.estado == e,
                      onSelected: (_) {
                        Navigator.pop(c);
                        if (e != r.estado) _actualizar(r, {'estado': e});
                      },
                    ),
                ],
              ),
            ] else
              const Text('Sólo el administrador o el agente asignado cambian prioridad y estado.',
                  style: TextStyle(color: kTenue, fontSize: 12.5)),
            if (esAdmin && agentes.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Asignar a', style: TextStyle(color: kTenue)),
              Wrap(
                spacing: 6,
                children: [
                  for (final a in agentes)
                    ActionChip(
                      avatar: Icon(Icons.circle, size: 10, color: a.conectado ? kVerde : kTenue),
                      label: Text(a.id == _yo.id ? 'A mí' : a.nombre),
                      onPressed: () async {
                        Navigator.pop(c);
                        await _intentar(() async {
                          await _api.asignar(r.id, a.id);
                          if (mounted) avisar(context, '${r.id} asignado a ${a.nombre}');
                          await _cargarReportes();
                        });
                      },
                    ),
                ],
              ),
            ],
            if (_rol == kRolAdmin) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(c);
                  await _intentar(() async {
                    await _api.eliminarReporte(r.id);
                    if (mounted) avisar(context, '${r.id} eliminado');
                    await _cargarReportes();
                  });
                },
                icon: const Icon(Icons.delete_outline, color: kNeonTexto),
                label: const Text('Eliminar reporte', style: TextStyle(color: kNeonTexto)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Mensajes ─────────────────────────────────────────────────

  Widget _tabMensajes() {
    final visibles = _mensajes.where((m) => m.id > _ocultarHasta).toList();
    final destinos = _participantes.where((p) => p.id != _yo.id).toList();
    return Column(
      children: [
        Container(
          color: kSuperficie,
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in _conteo)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${c.nombre}: ${c.total}', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      if (_conteo.isEmpty)
                        const Text('Sin mensajes enviados', style: TextStyle(color: kTenue, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Limpiar historial',
                icon: const Icon(Icons.delete_sweep_outlined, color: kTexto),
                onPressed: _limpiarHistorial,
              ),
            ],
          ),
        ),
        Expanded(
          child: visibles.isEmpty
              ? const Center(child: Text('Sin mensajes.', style: TextStyle(color: kTenue)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  children: [for (final m in visibles) _burbuja(m)],
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: kSuperficie,
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Para:', style: TextStyle(color: kTenue)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        dropdownColor: kSuperficie,
                        value: destinos.any((p) => p.id == _para) ? _para : null,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Todos', style: TextStyle(color: kTexto))),
                          for (final p in destinos)
                            DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text('${p.nombre} (${etiquetaRol(p.rolEfectivo ?? p.rol)})',
                                  style: const TextStyle(color: kTexto)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _para = v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Adjuntar imagen',
                      icon: const Icon(Icons.image_outlined, color: kTexto),
                      onPressed: _enviando ? null : _adjuntarImagen,
                    ),
                    IconButton(
                      tooltip: 'Adjuntar bitácora (.txt)',
                      icon: const Icon(Icons.description_outlined, color: kTexto),
                      onPressed: _enviando ? null : _adjuntarBitacora,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _texto,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        style: const TextStyle(color: kTexto),
                        decoration: campo('Escribe un mensaje').copyWith(counterText: ''),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: kNeon),
                      onPressed: _enviando ? null : () => _enviar(),
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _burbuja(MensajeSoporte m) {
    final mio = m.emisorId == _yo.id;
    final privado = m.paraId != null;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: mio ? kNeon.withValues(alpha: 0.85) : kSuperficie,
          borderRadius: BorderRadius.circular(12),
          border: privado ? Border.all(color: Colors.amber, width: 1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.emisorNombre} · ${etiquetaRol(m.emisorRol)}'
              '${privado ? ' → ${_nombreDe(m.paraId)}' : ''}'
              '${m.reporteId != null ? ' · ${m.reporteId}' : ''}',
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
            if (m.texto.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(m.texto, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
            ],
            if (m.archivoPath != null)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Colors.white),
                onPressed: () => _abrirArchivo(m),
                icon: Icon(m.esImagen ? Icons.image : Icons.attach_file, size: 16),
                label: Text(m.archivoNombre ?? 'archivo', overflow: TextOverflow.ellipsis),
              ),
            Text(horaCorta(m.hora), style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _enviar({String? archivoPath, String? archivoNombre}) async {
    final texto = _texto.text.trim();
    if (texto.isEmpty && archivoPath == null) {
      avisar(context, 'No se pueden enviar mensajes vacíos', error: true);
      return;
    }
    final datos = <String, dynamic>{
      'texto': texto,
      'para_id': _para,
      if (archivoPath != null) 'archivo_path': archivoPath,
      if (archivoNombre != null) 'archivo_nombre': archivoNombre,
    };
    setState(() => _enviando = true);
    try {
      final m = await _api.enviar(datos);
      if (!mounted) return;
      _texto.clear();
      avisar(context, 'Mensaje enviado ${m.paraId == null ? 'a todos' : 'a ${_nombreDe(m.paraId)}'} · ${horaCorta(m.hora)}');
      await _cargarMensajes();
    } on SoporteException catch (e) {
      if (!mounted) return;
      if (e.sinConexion && archivoPath == null) {
        _texto.clear();
        await _guardarPendiente('enviar_mensaje', datos);
      } else {
        avisar(context, e.mensaje, error: true);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _subirYEnviar(String nombre, Uint8List bytes) async {
    setState(() => _enviando = true);
    try {
      final subido = await _api.subirArchivo(nombre, bytes);
      if (!mounted) return;
      setState(() => _enviando = false);
      await _enviar(archivoPath: subido.path, archivoNombre: subido.nombre);
    } on SoporteException catch (e) {
      if (mounted) avisar(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _adjuntarImagen() async {
    final XFile? img;
    try {
      img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    } on PlatformException {
      if (mounted) avisar(context, 'No fue posible abrir la galería', error: true);
      return;
    }
    if (img == null) return;
    final bytes = await img.readAsBytes();
    await _subirYEnviar(img.name, bytes);
  }

  /// Archivo de texto generado en el teléfono: sirve para probar el envío
  /// de archivos aunque el emulador no tenga fotos.
  Future<void> _adjuntarBitacora() async {
    final ahora = DateTime.now();
    final contenido = 'Bitácora BabyWolf\n'
        'Dispositivo: ${_yo.dispositivo}\n'
        'Participante: ${_yo.nombre} (${etiquetaRol(_rol)})\n'
        'Reportes visibles: ${_reportes.length}\n'
        'Pendientes sin enviar: ${_pendientes.length}\n'
        'Generada: $ahora\n';
    final nombre = 'bitacora_${ahora.millisecondsSinceEpoch}.txt';
    await _subirYEnviar(nombre, Uint8List.fromList(utf8.encode(contenido)));
  }

  Future<void> _abrirArchivo(MensajeSoporte m) async {
    await _intentar(() async {
      final url = await _api.urlDescarga(m.archivoPath!);
      if (!mounted) return;
      Widget contenido;
      if (m.esImagen) {
        contenido = Image.network(url, errorBuilder: (_, _, _) => const Text('No se pudo cargar la imagen.'));
      } else {
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        contenido = SelectableText(utf8.decode(r.bodyBytes),
            style: const TextStyle(color: kTexto, fontFamily: 'monospace', fontSize: 12));
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: kSuperficie,
          title: Text(m.archivoNombre ?? 'Archivo', style: const TextStyle(color: kTexto, fontSize: 15)),
          content: SingleChildScrollView(child: contenido),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(c);
              },
              child: const Text('Copiar URL (5 min)'),
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
          ],
        ),
      );
    });
  }

  Future<void> _limpiarHistorial() async {
    final enServidor = puedeAdministrar(_rol);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Limpiar historial', style: TextStyle(color: kTexto)),
        content: Text(
          enServidor
              ? 'Se borra el historial de mensajes para TODOS los dispositivos.'
              : 'Se oculta el historial sólo en este teléfono (borrarlo para todos es del administrador).',
          style: const TextStyle(color: kTenue),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Limpiar')),
        ],
      ),
    );
    if (ok != true) return;
    if (enServidor) {
      await _intentar(() async {
        await _api.limpiarMensajes();
        if (mounted) avisar(context, 'Historial borrado para todos');
        await _cargarMensajes();
      });
    } else {
      setState(() => _ocultarHasta = _ultimoMensaje);
      avisar(context, 'Historial oculto en este teléfono');
    }
  }

  // ── Dispositivos ─────────────────────────────────────────────

  Widget _tabDispositivos() {
    final esAdmin = puedeAdministrar(_rol);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Seccion(
          titulo: 'Dispositivos (${_participantes.where((p) => p.conectado).length} conectados)',
          child: Column(
            children: [
              for (final p in _participantes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.smartphone, color: p.conectado ? kVerde : kTenue),
                  title: Text('${p.nombre}${p.id == _yo.id ? ' (yo)' : ''}',
                      style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${etiquetaRol(p.rolEfectivo ?? p.rol)} · ${p.dispositivo} · '
                    '${p.conectado ? 'conectado' : 'desconectado'}',
                    style: const TextStyle(color: kTenue, fontSize: 12.5),
                  ),
                  trailing: _rol == kRolAdmin && p.id != _yo.id
                      ? IconButton(
                          tooltip: 'Expulsar',
                          icon: const Icon(Icons.person_remove_outlined, color: kNeonTexto),
                          onPressed: () => _intentar(() async {
                            await _api.expulsar(p.id);
                            if (mounted) avisar(context, '${p.nombre} fue expulsado');
                            await _latido();
                          }),
                        )
                      : null,
                ),
            ],
          ),
        ),
        if (esAdmin)
          Seccion(
            titulo: 'Administración',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BotonPrincipal(texto: 'INVITAR AGENTE', icono: Icons.support_agent, onPressed: () => _invitar(kRolAgente)),
                const SizedBox(height: 8),
                BotonPrincipal(texto: 'INVITAR USUARIO', icono: Icons.person_add_alt, onPressed: () => _invitar(kRolUsuario)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _intentar(() async {
                    final n = await _api.asumirDesconectados();
                    if (mounted) avisar(context, n == 0 ? 'No hay reportes de agentes desconectados' : 'Asumiste $n reporte(s)');
                    await _cargarReportes();
                  }),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Asumir reportes de agentes desconectados'),
                ),
              ],
            ),
          ),
        Seccion(
          titulo: 'Mi conexión',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kNeon,
                value: _conectado,
                onChanged: _cambiarConexion,
                title: const Text('Conectado a la mesa', style: TextStyle(color: kTexto)),
                subtitle: const Text(
                  'Apágalo para simular una desconexión: si eres el admin, el agente te cubre; '
                  'si eres el agente, el admin puede asumir tus reportes.',
                  style: TextStyle(color: kTenue, fontSize: 12),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _cerrarSesion(),
                  icon: const Icon(Icons.logout, color: kNeonTexto),
                  label: const Text('Cerrar sesión en este teléfono', style: TextStyle(color: kNeonTexto)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _invitar(String rol) async {
    final nombreCtrl = TextEditingController(text: rol == kRolAgente ? 'Agente ' : 'Usuario ');
    final nombre = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSuperficie,
        title: Text('Invitar ${etiquetaRol(rol).toLowerCase()}', style: const TextStyle(color: kTexto)),
        content: TextField(
          controller: nombreCtrl,
          autofocus: true,
          maxLength: 40,
          style: const TextStyle(color: kTexto),
          decoration: campo('Nombre de quien entra'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, nombreCtrl.text), child: const Text('Generar URL')),
        ],
      ),
    );
    nombreCtrl.dispose();
    if (nombre == null || nombre.trim().isEmpty) return;
    await _intentar(() async {
      final url = await _api.invitar(rol, nombre.trim());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: kSuperficie,
          title: const Text('URL preasignada', style: TextStyle(color: kTexto)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rol: ${etiquetaRol(rol)} · un solo uso · vence en 30 minutos.',
                  style: const TextStyle(color: kTenue)),
              const SizedBox(height: 10),
              SelectableText(url, style: const TextStyle(color: kTexto, fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(c);
                avisar(context, 'URL copiada. Envíala al otro dispositivo.');
              },
              child: const Text('Copiar'),
            ),
          ],
        ),
      );
    });
  }
}

/// Formulario de alta de reporte (TC01, TC02 y TC03).
class _FormReporte extends StatefulWidget {
  const _FormReporte();

  @override
  State<_FormReporte> createState() => _FormReporteState();
}

class _FormReporteState extends State<_FormReporte> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _equipo = TextEditingController();
  final _descripcion = TextEditingController();
  String _tipo = 'falla';
  String _prioridad = 'Media';

  @override
  void dispose() {
    _id.dispose();
    _equipo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, <String, dynamic>{
      if (_id.text.trim().isNotEmpty) 'id': _id.text.trim().toUpperCase(),
      'equipo': _equipo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'tipo': _tipo,
      'prioridad': _prioridad,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nuevo reporte', style: TextStyle(color: kTexto, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _id,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: kTexto),
                decoration: campo('ID (opcional)', ayuda: 'Vacío = se numera solo. Ej. REP001'),
                validator: ValidadorReporte.id,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _equipo,
                style: const TextStyle(color: kTexto),
                decoration: campo('Equipo'),
                validator: ValidadorReporte.equipo,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descripcion,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(color: kTexto),
                decoration: campo('Descripción'),
                validator: ValidadorReporte.descripcion,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                dropdownColor: kSuperficie,
                style: const TextStyle(color: kTexto),
                decoration: campo('Tipo'),
                items: [
                  for (final e in kTipos.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'falla'),
              ),
              if (_tipo == 'acceso')
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Las solicitudes de acceso perdido van directo al administrador.',
                      style: TextStyle(color: kTenue, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _prioridad,
                dropdownColor: kSuperficie,
                style: const TextStyle(color: kTexto),
                decoration: campo('Prioridad'),
                items: [for (final p in kPrioridades) DropdownMenuItem(value: p, child: Text(p))],
                onChanged: (v) => setState(() => _prioridad = v ?? 'Media'),
              ),
              const SizedBox(height: 16),
              BotonPrincipal(texto: 'GUARDAR REPORTE', icono: Icons.save_outlined, onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}

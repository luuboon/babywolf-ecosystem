// Práctica 10 — Seguridad, autenticación y control de acceso a una base de
// datos compartida entre dispositivos.
//
// Fase 1: inicio de sesión y UID en pantalla.   Fase 2: incidencias con creado_por = UID.
// Fase 3: reglas RLS en Supabase (006_incidencias_rls.sql).
// Fase 4: pruebas autorizadas y no autorizadas.   Fase 5: bitácora de resultados.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'incidencias_api.dart';

/// Una fila de la matriz: qué se intentó, qué se esperaba y qué contestó la base.
class Registro {
  const Registro(this.hora, this.caso, this.accion, this.esperadoPermitido, this.resultado);
  final DateTime hora;
  final String caso;
  final String accion;
  final bool esperadoPermitido;
  final Resultado resultado;

  bool get pasa => resultado.codigo != 0 && resultado.permitido == esperadoPermitido;

  String get linea => '${horaCorta(hora)} | $caso | $accion | '
      'esperado: ${esperadoPermitido ? 'permitido' : 'rechazado'} | '
      'obtenido: ${resultado.permitido ? 'permitido' : 'rechazado'} (${resultado.detalle}) | '
      '${pasa ? 'PASA' : 'FALLA'}';
}

class IncidenciasScreen extends StatefulWidget {
  const IncidenciasScreen({super.key, this.api});

  final IncidenciasApi? api;

  @override
  State<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends State<IncidenciasScreen> {
  late final IncidenciasApi _api = widget.api ?? IncidenciasApi();

  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _uidAjeno = TextEditingController();
  final _idAjena = TextEditingController();

  SesionSupabase? _sesion;
  List<Incidencia> _mias = [];
  final List<Registro> _bitacora = [];
  bool _ocupado = false;
  bool _oculta = true;
  String? _errorLogin;

  @override
  void dispose() {
    for (final c in [_email, _contrasena, _titulo, _descripcion, _uidAjeno, _idAjena]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _token => _sesion?.token;

  void _registrar(String caso, String accion, bool esperadoPermitido, Resultado r) {
    final reg = Registro(DateTime.now(), caso, accion, esperadoPermitido, r);
    setState(() => _bitacora.insert(0, reg));
    // Sólo el caso y el resultado: nunca tokens ni contraseñas (práctica 5).
    debugPrint('[P10] ${reg.linea}');
    avisar(context, '$caso: ${r.permitido ? 'permitido' : 'rechazado'} · ${reg.pasa ? 'PASA' : 'FALLA'}',
        error: !reg.pasa);
  }

  Future<void> _ocupar(Future<void> Function() f) async {
    setState(() => _ocupado = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // ── Fase 1 ──────────────────────────────────────────────────

  Future<void> _entrar() async {
    final email = _email.text.trim();
    final pass = _contrasena.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorLogin = 'Escribe correo y contraseña.');
      return;
    }
    await _ocupar(() async {
      try {
        final s = await _api.entrar(email, pass);
        if (!mounted) return;
        setState(() {
          _sesion = s;
          _errorLogin = null;
        });
        _registrar('SEG-01', 'Inicio de sesión de ${s.email}', true,
            const Resultado(permitido: true, codigo: 200, filas: 1, detalle: 'Sesión iniciada.'));
        await _recargar();
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() => _errorLogin = e.mensaje);
        _registrar('SEG-02', 'Inicio de sesión de $email', false,
            Resultado(permitido: false, codigo: 400, filas: 0, detalle: e.mensaje));
      } finally {
        _contrasena.clear();
      }
    });
  }

  Future<void> _salir() async {
    final s = _sesion;
    if (s == null) return;
    await _api.salir(s);
    if (!mounted) return;
    setState(() {
      _sesion = null;
      _mias = [];
    });
    avisar(context, 'Sesión cerrada');
  }

  Future<void> _recargar() async {
    final r = await _api.listar(_token);
    if (!mounted) return;
    setState(() => _mias = r.datos.map(Incidencia.desdeJson).toList());
  }

  // ── Fase 2 ──────────────────────────────────────────────────

  Future<void> _crear() async {
    final s = _sesion;
    if (s == null) return;
    if (_titulo.text.trim().isEmpty) {
      avisar(context, 'El título es obligatorio', error: true);
      return;
    }
    await _ocupar(() async {
      final r = await _api.crear(s.token, titulo: _titulo.text, descripcion: _descripcion.text, creadoPor: s.uid);
      if (!mounted) return;
      _registrar('SEG-03', 'Crear "${_titulo.text.trim()}" con mi UID', true, r);
      if (r.permitido) {
        _titulo.clear();
        _descripcion.clear();
      }
      await _recargar();
    });
  }

  Future<void> _estadoPropio(Incidencia i, String estado) => _ocupar(() async {
        final r = await _api.cambiarEstado(_token, i.id, estado);
        if (!mounted) return;
        _registrar('SEG-08', 'Cambiar mi incidencia a "$estado"', true, r);
        await _recargar();
      });

  Future<void> _eliminarPropia(Incidencia i) => _ocupar(() async {
        final r = await _api.eliminar(_token, i.id);
        if (!mounted) return;
        _registrar('PROPIA', 'Eliminar mi incidencia "${i.titulo}"', true, r);
        await _recargar();
      });

  // ── Fase 4: intentos no autorizados ─────────────────────────

  bool _validarAjeno({bool uid = false, bool id = false}) {
    if (uid && !IncidenciasApi.esUuid(_uidAjeno.text)) {
      avisar(context, 'Pega el UID del otro usuario (lo muestra su dispositivo)', error: true);
      return false;
    }
    if (id && !IncidenciasApi.esUuid(_idAjena.text)) {
      avisar(context, 'Pega el ID de una incidencia del otro usuario', error: true);
      return false;
    }
    return true;
  }

  Future<void> _seg04() async {
    if (!_validarAjeno(uid: true)) return;
    await _ocupar(() async {
      final r = await _api.crear(_token,
          titulo: 'Suplantación', descripcion: 'Creada con UID ajeno', creadoPor: _uidAjeno.text);
      if (mounted) _registrar('SEG-04', 'Crear incidencia con el UID del otro usuario', false, r);
    });
  }

  Future<void> _seg05() async {
    if (!_validarAjeno(id: true)) return;
    await _ocupar(() async {
      final r = await _api.leer(_token, _idAjena.text);
      if (mounted) _registrar('SEG-05', 'Leer la incidencia ajena por su ID', false, r);
    });
  }

  Future<void> _seg06() async {
    if (!_validarAjeno(id: true)) return;
    await _ocupar(() async {
      final r = await _api.cambiarEstado(_token, _idAjena.text, 'cerrada');
      if (mounted) _registrar('SEG-06', 'Cerrar la incidencia ajena', false, r);
    });
  }

  Future<void> _seg07() async {
    if (!_validarAjeno(id: true)) return;
    await _ocupar(() async {
      final r = await _api.eliminar(_token, _idAjena.text);
      if (mounted) _registrar('SEG-07', 'Eliminar la incidencia ajena', false, r);
    });
  }

  Future<void> _seg09() async {
    if (!_validarAjeno(uid: true)) return;
    if (_mias.isEmpty) {
      avisar(context, 'Primero crea una incidencia propia', error: true);
      return;
    }
    final propia = _mias.first;
    await _ocupar(() async {
      final r = await _api.cambiarPropietario(_token, propia.id, _uidAjeno.text);
      if (!mounted) return;
      _registrar('SEG-09', 'Pasar "${propia.titulo}" al otro usuario', false, r);
      await _recargar();
    });
  }

  /// SEG-10: las mismas peticiones, pero sin el JWT (como si no hubiera sesión).
  Future<void> _seg10() => _ocupar(() async {
        final lectura = await _api.listar(null);
        if (!mounted) return;
        _registrar('SEG-10', 'Sin sesión: leer incidencias', false, lectura);
        final escritura = await _api.crear(null,
            titulo: 'Anónima', descripcion: '', creadoPor: _sesion?.uid ?? '00000000-0000-0000-0000-000000000000');
        if (!mounted) return;
        _registrar('SEG-10', 'Sin sesión: crear incidencia', false, escritura);
      });

  Future<void> _pegar(TextEditingController c) async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => c.text = d!.text!.trim());
  }

  void _copiar(String texto, String que) {
    Clipboard.setData(ClipboardData(text: texto));
    avisar(context, '$que copiado');
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = _sesion;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('Incidencias seguras', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
        actions: [
          if (s != null)
            IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh, color: kTexto), onPressed: _recargar),
          if (s != null)
            IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout, color: kTexto), onPressed: _salir),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _ocupado,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (s == null) _login() else ...[_sesionCard(s), _nueva(), _lista(), _pruebas()],
            if (s == null) _sinSesion(),
            _bitacoraWidget(),
          ],
        ),
      ),
    );
  }

  Widget _login() {
    return Seccion(
      titulo: 'Fase 1 · Iniciar sesión',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Usa una de las dos cuentas de prueba (usuario A en un dispositivo, usuario B en el otro).',
            style: TextStyle(color: kTenue, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: kTexto),
            decoration: campo('Correo'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contrasena,
            obscureText: _oculta,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: kTexto),
            decoration: campo(
              'Contraseña',
              error: _errorLogin,
              sufijo: IconButton(
                icon: Icon(_oculta ? Icons.visibility_off : Icons.visibility, color: kTenue),
                onPressed: () => setState(() => _oculta = !_oculta),
              ),
            ),
            onSubmitted: (_) => _entrar(),
          ),
          const SizedBox(height: 12),
          BotonPrincipal(texto: 'ENTRAR', icono: Icons.login, onPressed: _ocupado ? null : _entrar),
        ],
      ),
    );
  }

  Widget _sinSesion() {
    return Seccion(
      titulo: 'SEG-10 · Acceso sin autenticación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Intenta leer y crear incidencias sin iniciar sesión (sólo con la llave pública).',
            style: TextStyle(color: kTenue, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _ocupado ? null : _seg10, child: const Text('Intentar sin sesión')),
        ],
      ),
    );
  }

  Widget _sesionCard(SesionSupabase s) {
    return Seccion(
      titulo: 'Fase 1 · Usuario autenticado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.email, style: const TextStyle(color: kTexto, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('UID', style: TextStyle(color: kTenue, fontSize: 12)),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  s.uid,
                  style: const TextStyle(color: kNeonTexto, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'Copiar UID',
                icon: const Icon(Icons.copy, color: kTenue, size: 18),
                onPressed: () => _copiar(s.uid, 'UID'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nueva() {
    return Seccion(
      titulo: 'Fase 2 · Nueva incidencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titulo,
            maxLength: 80,
            style: const TextStyle(color: kTexto),
            decoration: campo('Título'),
          ),
          TextField(
            controller: _descripcion,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(color: kTexto),
            decoration: campo('Descripción'),
          ),
          Text('creado_por = ${_sesion?.uid ?? ''}',
              style: const TextStyle(color: kTenue, fontSize: 11.5, fontFamily: 'monospace')),
          const SizedBox(height: 10),
          BotonPrincipal(texto: 'REGISTRAR', icono: Icons.add, onPressed: _ocupado ? null : _crear),
        ],
      ),
    );
  }

  Widget _lista() {
    return Seccion(
      titulo: 'Mis incidencias (${_mias.length})',
      child: _mias.isEmpty
          ? const Text('No tienes incidencias. La base sólo te devuelve las tuyas.',
              style: TextStyle(color: kTenue))
          : Column(
              children: [
                for (final i in _mias)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kFondo, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(i.titulo,
                                  style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline, color: kNeonTexto, size: 20),
                              onPressed: () => _eliminarPropia(i),
                            ),
                          ],
                        ),
                        if (i.descripcion.isNotEmpty)
                          Text(i.descripcion, style: const TextStyle(color: kTenue, fontSize: 13)),
                        Row(
                          children: [
                            Expanded(
                              child: Text('ID ${i.id}',
                                  style: const TextStyle(color: kTenue, fontSize: 11, fontFamily: 'monospace')),
                            ),
                            IconButton(
                              tooltip: 'Copiar ID',
                              icon: const Icon(Icons.copy, color: kTenue, size: 16),
                              onPressed: () => _copiar(i.id, 'ID'),
                            ),
                          ],
                        ),
                        Text('Propietario ${i.creadoPor}',
                            style: const TextStyle(color: kTenue, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final e in const ['abierta', 'en_proceso', 'cerrada'])
                              ChoiceChip(
                                label: Text(e),
                                selected: i.estado == e,
                                onSelected: (_) {
                                  if (e != i.estado) _estadoPropio(i, e);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _campoAjeno(TextEditingController c, String etiqueta) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        autocorrect: false,
        style: const TextStyle(color: kTexto, fontSize: 12.5, fontFamily: 'monospace'),
        decoration: campo(
          etiqueta,
          sufijo: IconButton(
            tooltip: 'Pegar',
            icon: const Icon(Icons.content_paste, color: kTenue),
            onPressed: () => _pegar(c),
          ),
        ),
      ),
    );
  }

  Widget _pruebas() {
    Widget boton(String caso, String texto, VoidCallback f) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: OutlinedButton(
            onPressed: _ocupado ? null : f,
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
            child: Text('$caso · $texto', style: const TextStyle(color: kTexto)),
          ),
        );
    return Seccion(
      titulo: 'Fase 4 · Intentos no autorizados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'La app manda la petición sin filtrar nada: si la base la rechaza, la regla funciona en el servidor.',
            style: TextStyle(color: kTenue, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _campoAjeno(_uidAjeno, 'UID del otro usuario'),
          _campoAjeno(_idAjena, 'ID de una incidencia del otro usuario'),
          boton('SEG-04', 'Crear con el UID del otro', _seg04),
          boton('SEG-05', 'Leer su incidencia', _seg05),
          boton('SEG-06', 'Modificar su incidencia', _seg06),
          boton('SEG-07', 'Eliminar su incidencia', _seg07),
          boton('SEG-09', 'Pasarle mi incidencia (cambiar propietario)', _seg09),
          boton('SEG-10', 'Leer y crear sin sesión', _seg10),
        ],
      ),
    );
  }

  Widget _bitacoraWidget() {
    final pasan = _bitacora.where((r) => r.pasa).length;
    return Seccion(
      titulo: 'Fase 5 · Bitácora (${_bitacora.length} operaciones, $pasan pasan)',
      accion: _bitacora.isEmpty
          ? null
          : IconButton(
              tooltip: 'Copiar bitácora',
              icon: const Icon(Icons.copy_all, color: kTenue, size: 20),
              onPressed: () => _copiar(_bitacora.reversed.map((r) => r.linea).join('\n'), 'Bitácora'),
            ),
      child: _bitacora.isEmpty
          ? const Text('Aquí aparece cada operación, exitosa o rechazada.', style: TextStyle(color: kTenue))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in _bitacora)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(r.pasa ? Icons.check_circle : Icons.cancel,
                            color: r.pasa ? kVerde : kNeon, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.caso} · ${r.accion}',
                                  style: const TextStyle(color: kTexto, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                '${horaCorta(r.hora)} · ${r.resultado.permitido ? 'permitido' : 'rechazado'} · ${r.resultado.detalle}',
                                style: const TextStyle(color: kTenue, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

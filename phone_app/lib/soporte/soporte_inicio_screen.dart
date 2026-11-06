// Práctica 7 — Mesa de ayuda del equipo de BabyWolf.
//
// Es donde el equipo coordina la atención de los reportes de los lectores y
// otras fallas del sitio, entre varios dispositivos y con roles:
// - El ADMINISTRADOR entra con la cuenta admin con la que ya inició sesión en
//   la app (la misma de la web).
// - El AGENTE y los USUARIOS entran con la URL preasignada que les genera el
//   administrador: la URL ya trae el rol firmado, nadie elige su propio rol.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart' as app;
import '../core/widgets.dart';
import '../cuenta/entrar_screen.dart';
import '../theme.dart';
import 'almacen_soporte.dart';
import 'modelos.dart';
import 'soporte_api.dart';
import 'soporte_panel_screen.dart';

class SoporteInicioScreen extends StatefulWidget {
  const SoporteInicioScreen({super.key});

  @override
  State<SoporteInicioScreen> createState() => _SoporteInicioScreenState();
}

class _SoporteInicioScreenState extends State<SoporteInicioScreen> {
  final _api = SoporteApi();
  final _url = TextEditingController();
  final _dispositivo = TextEditingController(text: 'Teléfono');

  AlmacenSoporte? _almacen;
  InfoInvitacion? _info;
  Uri? _urlValida;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _revisarSesion();
  }

  @override
  void dispose() {
    _url.dispose();
    _dispositivo.dispose();
    super.dispose();
  }

  /// TC08: si ya había sesión guardada, se entra directo.
  Future<void> _revisarSesion() async {
    final almacen = await AlmacenSoporte.abrir();
    final s = await almacen.leerSesion();
    if (!mounted) return;
    setState(() => _almacen = almacen);
    if (s != null) _abrirPanel(s);
  }

  void _abrirPanel(Sesion s) {
    _api.token = s.token;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => SoportePanelScreen(api: _api, almacen: _almacen!, yo: s.yo)),
    );
  }

  Future<void> _ejecutar(Future<Sesion> Function() accion) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final s = await accion();
      await _almacen!.guardarSesion(s);
      if (mounted) _abrirPanel(s);
    } on SoporteException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on app.AuthFallo catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// El JWT es el de la sesión de la app; el backend comprueba en la base
  /// que esa cuenta sea admin antes de abrir la mesa.
  void _entrarAdmin() {
    final sesion = context.read<app.Sesion>();
    _ejecutar(() async => _api.sesionAdmin(await sesion.token(), _dispositivo.text));
  }

  Future<void> _pegar() async {
    final datos = await Clipboard.getData(Clipboard.kTextPlain);
    if (datos?.text != null) {
      _url.text = datos!.text!.trim();
      _verificar();
    }
  }

  Future<void> _verificar() async {
    final u = SoporteApi.urlInvitacion(_url.text);
    setState(() {
      _info = null;
      _urlValida = null;
      _error = u == null ? 'Eso no parece una URL de invitación de BabyWolf.' : null;
    });
    if (u == null) return;
    setState(() => _ocupado = true);
    try {
      final info = await _api.verInvitacion(u);
      if (!mounted) return;
      setState(() {
        _info = info;
        _urlValida = u;
        if (info.usada) _error = 'Esta invitación ya fue usada en otro dispositivo.';
      });
    } on SoporteException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('Mesa de ayuda', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: _almacen == null
          ? const Center(child: CircularProgressIndicator(color: kNeon))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const Text(
                  'Reportes de fallas, procesos de atención y accesos perdidos entre 4 dispositivos: '
                  'administrador, agente y dos usuarios.',
                  style: TextStyle(color: kTenue, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _dispositivo,
                  maxLength: 40,
                  style: const TextStyle(color: kTexto),
                  decoration: campo('Nombre de este dispositivo', ayuda: 'Ej. Pixel de Abraham'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: kNeonTexto, fontWeight: FontWeight.w600)),
                  ),
                Seccion(
                  titulo: 'Unirme con invitación (agente o usuario)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _url,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(color: kTexto, fontSize: 12.5),
                        decoration: campo(
                          'URL preasignada',
                          sufijo: IconButton(
                            tooltip: 'Pegar',
                            icon: const Icon(Icons.content_paste, color: kTenue),
                            onPressed: _ocupado ? null : _pegar,
                          ),
                        ),
                        onSubmitted: (_) => _verificar(),
                      ),
                      const SizedBox(height: 10),
                      if (_info == null)
                        OutlinedButton(
                          onPressed: _ocupado ? null : _verificar,
                          child: const Text('VERIFICAR URL'),
                        )
                      else ...[
                        Text(
                          'Entrarás como ${etiquetaRol(_info!.rol)}: ${_info!.nombre}'
                          '${_info!.expira != null ? '\nLa invitación vence a las ${horaCorta(_info!.expira!)}' : ''}',
                          style: const TextStyle(color: kTexto, height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        BotonPrincipal(
                          texto: 'UNIRME',
                          icono: Icons.login,
                          onPressed: _ocupado || _info!.usada
                              ? null
                              : () => _ejecutar(() => _api.unirse(_urlValida!, _dispositivo.text)),
                        ),
                      ],
                    ],
                  ),
                ),
                Seccion(
                  titulo: 'Administrador (cuenta del blog)',
                  child: _admin(),
                ),
              ],
            ),
    );
  }

  Widget _admin() {
    final sesion = context.watch<app.Sesion>();
    final cuenta = sesion.cuenta;
    if (cuenta == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Inicia sesión con tu cuenta admin para abrir la mesa.', style: TextStyle(color: kTenue)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => EntrarScreen.abrir(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('INICIAR SESIÓN'),
          ),
        ],
      );
    }
    if (!cuenta.esAdmin) {
      return Text(
        'Tu cuenta (${cuenta.apodo}) no es admin del blog. Entra con la invitación que te comparta el admin.',
        style: const TextStyle(color: kTenue, height: 1.4),
      );
    }
    return BotonPrincipal(
      texto: 'ABRIR MESA COMO ${cuenta.apodo.toUpperCase()}',
      icono: Icons.admin_panel_settings_outlined,
      onPressed: _ocupado ? null : _entrarAdmin,
    );
  }
}

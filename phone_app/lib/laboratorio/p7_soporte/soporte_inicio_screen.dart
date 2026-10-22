// Práctica 7 — Entrada a la mesa de ayuda.
//
// - El ADMINISTRADOR entra con su cuenta del blog BabyWolf (Supabase).
// - El AGENTE y los USUARIOS entran con la URL preasignada que les genera el
//   administrador: la URL ya trae el rol firmado, nadie elige su propio rol.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'almacen_soporte.dart';
import 'modelos.dart';
import 'soporte_api.dart';
import 'soporte_panel_screen.dart';
import 'supabase_login.dart';

class SoporteInicioScreen extends StatefulWidget {
  const SoporteInicioScreen({super.key});

  @override
  State<SoporteInicioScreen> createState() => _SoporteInicioScreenState();
}

class _SoporteInicioScreenState extends State<SoporteInicioScreen> {
  final _api = SoporteApi();
  final _formAdmin = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _url = TextEditingController();
  final _dispositivo = TextEditingController(text: 'Teléfono');

  AlmacenSoporte? _almacen;
  InfoInvitacion? _info;
  Uri? _urlValida;
  bool _ocupado = false;
  bool _oculta = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _revisarSesion();
  }

  @override
  void dispose() {
    _email.dispose();
    _contrasena.dispose();
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
    } finally {
      _contrasena.clear(); // la contraseña no se queda en memoria de la pantalla
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _entrarAdmin() {
    if (!(_formAdmin.currentState?.validate() ?? false)) return;
    final email = _email.text;
    final pass = _contrasena.text;
    _ejecutar(() async {
      final jwt = await SupabaseLogin().entrar(email, pass);
      return _api.sesionAdmin(jwt, _dispositivo.text);
    });
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
                  child: Form(
                    key: _formAdmin,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: const TextStyle(color: kTexto),
                          decoration: campo('Correo'),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Escribe tu correo';
                            if (t.length > 120 || !t.contains('@') || t.contains(' ')) return 'Correo no válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _contrasena,
                          obscureText: _oculta,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          style: const TextStyle(color: kTexto),
                          decoration: campo(
                            'Contraseña',
                            sufijo: IconButton(
                              icon: Icon(_oculta ? Icons.visibility_off : Icons.visibility, color: kTenue),
                              onPressed: () => setState(() => _oculta = !_oculta),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return 'Escribe tu contraseña';
                            if (v!.length > 72) return 'Máximo 72 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        BotonPrincipal(
                          texto: 'ENTRAR COMO ADMINISTRADOR',
                          icono: Icons.admin_panel_settings_outlined,
                          onPressed: _ocupado ? null : _entrarAdmin,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

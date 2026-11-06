// Entrar o crear cuenta de BabyWolf (Práctica 5: AccesoSeguro).
//
// Lo que se cumple aquí:
// - Validación de cada campo antes de enviar (Validar en core/validacion.dart).
// - Contraseña oculta, sin autocorrector ni sugerencias del teclado.
// - Mensaje genérico si falla: no se dice si el correo existe.
// - 5 fallos seguidos bloquean el botón 30 s, con cuenta regresiva.
// - La contraseña se borra del campo al terminar cada intento.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../core/validacion.dart';
import '../core/widgets.dart';
import '../theme.dart';

class EntrarScreen extends StatelessWidget {
  const EntrarScreen({super.key});

  /// Abre el formulario desde cualquier pantalla (p. ej. "Inicia sesión para
  /// comentar") y regresa al entrar.
  static Future<void> abrir(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EntrarScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(iconTheme: const IconThemeData(color: kTexto)),
      body: EntrarFormulario(alEntrar: () => Navigator.of(context).pop()),
    );
  }
}

class EntrarFormulario extends StatefulWidget {
  const EntrarFormulario({super.key, this.alEntrar});

  final VoidCallback? alEntrar;

  @override
  State<EntrarFormulario> createState() => _EntrarFormularioState();
}

class _EntrarFormularioState extends State<EntrarFormulario> {
  final _form = GlobalKey<FormState>();
  final _apodo = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();

  bool _crear = false;
  bool _oculta = true;
  bool _ocupado = false;
  String? _error;
  String? _aviso;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca la cuenta regresiva del bloqueo.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<Sesion>().limite.bloqueoRestante != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _apodo.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _error = null;
      _aviso = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    final sesion = context.read<Sesion>();
    setState(() => _ocupado = true);
    try {
      if (_crear) {
        final dentro = await sesion.registrarse(_apodo.text, _correo.text, _contrasena.text);
        if (!dentro) {
          if (mounted) {
            setState(() {
              _crear = false;
              _aviso = 'Cuenta creada. Te enviamos un correo para confirmarla; después inicia sesión aquí.';
            });
          }
          return;
        }
      } else {
        await sesion.entrar(_correo.text, _contrasena.text);
      }
      if (mounted) {
        avisar(context, 'Hola, ${sesion.cuenta?.apodo ?? ''}');
        widget.alEntrar?.call();
      }
    } on AuthFallo catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      // La contraseña no se queda en la pantalla.
      _contrasena.clear();
      _confirmar.clear();
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloqueo = context.watch<Sesion>().limite.bloqueoRestante;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            _crear ? 'Crear cuenta' : 'Iniciar sesión',
            style: const TextStyle(color: kTexto, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Es la misma cuenta del blog BabyWolf en la web. Con ella comentas noticias y reportas problemas.',
            style: TextStyle(color: kTenue, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (_crear) ...[
            TextFormField(
              controller: _apodo,
              maxLength: Validar.maxApodo,
              autocorrect: false,
              style: const TextStyle(color: kTexto),
              decoration: campo('Nombre de usuario', ayuda: 'Así te verán en los comentarios'),
              validator: Validar.apodo,
            ),
            const SizedBox(height: 6),
          ],
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            maxLength: Validar.maxCorreo,
            style: const TextStyle(color: kTexto),
            decoration: campo('Correo'),
            validator: Validar.correo,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _contrasena,
            obscureText: _oculta,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            maxLength: Validar.maxContrasena,
            style: const TextStyle(color: kTexto),
            decoration: campo(
              'Contraseña',
              ayuda: _crear ? 'Mínimo ${Validar.minContrasenaNueva} caracteres, con letras y números' : null,
              sufijo: IconButton(
                tooltip: _oculta ? 'Mostrar' : 'Ocultar',
                icon: Icon(_oculta ? Icons.visibility_off : Icons.visibility, color: kTenue),
                onPressed: () => setState(() => _oculta = !_oculta),
              ),
            ),
            validator: _crear ? Validar.contrasenaNueva : Validar.contrasena,
          ),
          if (_crear) ...[
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmar,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              style: const TextStyle(color: kTexto),
              decoration: campo('Repite la contraseña'),
              validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden' : null,
            ),
          ],
          const SizedBox(height: 14),
          if (bloqueo != null)
            _mensaje(Icons.timer_outlined, 'Demasiados intentos. Espera ${bloqueo.inSeconds + 1} s para volver a intentar.')
          else if (_error != null)
            _mensaje(Icons.error_outline, _error!),
          if (_aviso != null) _mensaje(Icons.mark_email_read_outlined, _aviso!, color: kVerde),
          BotonPrincipal(
            texto: _ocupado ? 'UN MOMENTO…' : (_crear ? 'CREAR CUENTA' : 'ENTRAR'),
            icono: _crear ? Icons.person_add_alt : Icons.lock_open,
            onPressed: _ocupado || bloqueo != null ? null : _enviar,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _ocupado
                ? null
                : () => setState(() {
                      _crear = !_crear;
                      _error = null;
                      _form.currentState?.reset();
                    }),
            child: Text(_crear ? 'Ya tengo cuenta: iniciar sesión' : '¿No tienes cuenta? Crear una'),
          ),
        ],
      ),
    );
  }

  Widget _mensaje(IconData icono, String texto, {Color color = kNeonTexto}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

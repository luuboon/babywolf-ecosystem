// Práctica 5 — AccesoSeguro: inicio de sesión simulado con código seguro.
//
// 1. Campos usuario y contraseña.        5. Errores genéricos.
// 2. Ambos obligatorios.                 6. Nada sensible en Logcat.
// 3. Longitud máxima.                    7. Acceso simulado con datos de prueba.
// 4. Contraseña oculta.
// + usuario de puros espacios rechazado y contraseña de 8 o más caracteres.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'log_seguro.dart';
import 'validador_acceso.dart';

class AccesoSeguroScreen extends StatefulWidget {
  const AccesoSeguroScreen({super.key});

  @override
  State<AccesoSeguroScreen> createState() => _AccesoSeguroScreenState();
}

class _AccesoSeguroScreenState extends State<AccesoSeguroScreen> {
  /// Mensaje único para cualquier credencial incorrecta: no dice si falló el
  /// usuario o la contraseña, para no ayudar a adivinar cuentas.
  static const errorGenerico = 'Usuario o contraseña incorrectos.';

  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  final _limite = LimiteIntentos();

  bool _oculta = true;
  bool _verificando = false;
  String? _error;
  String? _bienvenida;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca la cuenta regresiva del bloqueo.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _limite.bloqueoRestante != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _bienvenida = null;
    });
    if (_limite.bloqueoRestante != null) return;
    if (!(_form.currentState?.validate() ?? false)) {
      LogSeguro.registrar('validacion_rechazada');
      return;
    }

    setState(() => _verificando = true);
    // Pequeña espera fija: el tiempo de respuesta no cambia según qué falló.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final usuario = _usuario.text.trim();
    final ok = CredencialesPrueba.verificar(usuario, _contrasena.text);
    // La contraseña se borra del campo en cuanto se usa, salió bien o mal.
    _contrasena.clear();
    if (!mounted) return;

    if (ok) {
      _limite.exito();
      LogSeguro.registrar('acceso_concedido', usuario: usuario);
      setState(() {
        _verificando = false;
        _bienvenida = 'Acceso concedido (simulado). Bienvenido, $usuario.';
      });
    } else {
      _limite.fallo();
      LogSeguro.registrar('acceso_denegado', usuario: usuario);
      setState(() {
        _verificando = false;
        _error = errorGenerico;
      });
    }
  }

  void _datosPrueba() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Datos de prueba', style: TextStyle(color: kTexto)),
        content: const Text(
          'Usuario: alumno.uteq\n\n'
          'La contraseña de prueba está en docs/practicas/practica5_acceso_seguro.md. '
          'La app no la contiene: sólo guarda y compara su hash SHA-256.',
          style: TextStyle(color: kTenue, height: 1.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloqueo = _limite.bloqueoRestante;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('AccesoSeguro', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Datos de prueba',
            icon: const Icon(Icons.info_outline, color: kTexto),
            onPressed: _datosPrueba,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Iniciar sesión',
            style: TextStyle(color: kTexto, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Sistema interno (acceso simulado)', style: TextStyle(color: kTenue)),
          const SizedBox(height: 18),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  key: const Key('campo_usuario'),
                  controller: _usuario,
                  style: const TextStyle(color: kTexto),
                  decoration: campo('Usuario'),
                  // Se muestra el contador pero NO se trunca: así una entrada
                  // demasiado larga se rechaza con un mensaje (requisito 3).
                  maxLength: ValidadorAcceso.maxUsuario,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  validator: ValidadorAcceso.usuario,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('campo_contrasena'),
                  controller: _contrasena,
                  style: const TextStyle(color: kTexto),
                  obscureText: _oculta,
                  autocorrect: false,
                  enableSuggestions: false,
                  // El teclado no aprende ni sugiere lo que se escribe aquí.
                  enableIMEPersonalizedLearning: false,
                  keyboardType: TextInputType.visiblePassword,
                  maxLength: ValidadorAcceso.maxContrasena,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  validator: ValidadorAcceso.contrasena,
                  onFieldSubmitted: (_) => _entrar(),
                  decoration: campo(
                    'Contraseña',
                    ayuda: 'Mínimo ${ValidadorAcceso.minContrasena} caracteres',
                    sufijo: IconButton(
                      tooltip: _oculta ? 'Mostrar' : 'Ocultar',
                      icon: Icon(_oculta ? Icons.visibility_off : Icons.visibility, color: kTenue),
                      onPressed: () => setState(() => _oculta = !_oculta),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: BotonPrincipal(
              texto: _verificando ? 'VERIFICANDO...' : 'ENTRAR',
              icono: Icons.lock_open,
              onPressed: _verificando || bloqueo != null ? null : _entrar,
            ),
          ),
          const SizedBox(height: 14),
          if (bloqueo != null)
            _mensaje(
              Icons.timer_outlined,
              'Demasiados intentos. Espera ${bloqueo.inSeconds + 1} s para volver a intentar.',
              kNeon,
            )
          else if (_error != null)
            _mensaje(Icons.error_outline, _error!, kNeon),
          if (_bienvenida != null) _mensaje(Icons.verified_user, _bienvenida!, kVerde),
          const SizedBox(height: 10),
          Seccion(
            titulo: 'Registro seguro (lo que vería Logcat)',
            child: LogSeguro.eventos.isEmpty
                ? const Text('Sin eventos todavía.', style: TextStyle(color: kTenue))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in LogSeguro.eventos.take(8))
                        Text(
                          '${horaCorta(e.hora)}  ${e.texto}',
                          style: const TextStyle(color: kTenue, fontSize: 12, fontFamily: 'monospace'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mensaje(IconData icono, String texto, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

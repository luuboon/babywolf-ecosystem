// Sección de comentarios al final de una noticia (Práctica 6).
//
// - Cada comentario muestra autor y hora; arriba, el total y cuántos son tuyos.
// - Se consulta cada 5 s mientras la noticia está abierta: lo que comenta otro
//   teléfono aparece solo.
// - Sin sesión se leen, pero para comentar hay que entrar con la cuenta.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../core/supabase.dart';
import '../core/widgets.dart';
import '../cuenta/entrar_screen.dart';
import '../models/post.dart';
import '../theme.dart';
import 'comentarios_api.dart';

class ComentariosSeccion extends StatefulWidget {
  const ComentariosSeccion({super.key, required this.post, this.api});

  final Post post;
  final ComentariosApi? api;

  @override
  State<ComentariosSeccion> createState() => _ComentariosSeccionState();
}

class _ComentariosSeccionState extends State<ComentariosSeccion> {
  late final ComentariosApi _api = widget.api ?? ComentariosApi();
  final _texto = TextEditingController();
  Timer? _timer;

  List<Comentario>? _lista;
  String? _error;
  String? _errorEnvio;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
    _leer();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _leer());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _leer() async {
    if (widget.post.id.isEmpty) return;
    final sesion = context.read<Sesion>();
    try {
      final lista = await _api.listar(widget.post.id, token: await sesion.tokenOpcional());
      if (mounted) {
        setState(() {
          _lista = lista;
          _error = null;
        });
      }
    } on SinConexion {
      if (mounted) setState(() => _error = 'Sin conexión: los comentarios pueden no estar al día.');
    } on ComentarioFallo catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _enviar() async {
    final invalido = ReglasComentario.validar(_texto.text);
    if (invalido != null) {
      setState(() => _errorEnvio = invalido);
      return;
    }
    final sesion = context.read<Sesion>();
    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });
    try {
      final c = await _api.publicar(await sesion.token(), widget.post.id, _texto.text);
      _texto.clear();
      if (mounted) {
        setState(() => _lista = [...?_lista, c]);
        FocusScope.of(context).unfocus();
      }
    } on SinConexion catch (e) {
      // No se finge éxito: el texto se queda en el campo para reintentar.
      if (mounted) setState(() => _errorEnvio = e.mensaje);
    } on AuthFallo catch (e) {
      if (mounted) setState(() => _errorEnvio = e.mensaje);
    } on ComentarioFallo catch (e) {
      if (mounted) setState(() => _errorEnvio = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _borrar(Comentario c) async {
    final sesion = context.read<Sesion>();
    try {
      final ok = await _api.borrar(await sesion.token(), c.id);
      if (!mounted) return;
      if (ok) {
        setState(() => _lista = _lista?.where((x) => x.id != c.id).toList());
        avisar(context, 'Comentario borrado');
      } else {
        avisar(context, 'No se pudo borrar: no es tu comentario.', error: true);
      }
    } on Exception catch (e) {
      if (mounted) avisar(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final yo = sesion.cuenta;
    final lista = _lista;
    final mios = lista == null || yo == null ? 0 : (ReglasComentario.conteo(lista)[yo.uid] ?? 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0x22FFFFFF)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'COMENTARIOS${lista == null ? '' : ' · ${lista.length}'}',
                style: const TextStyle(color: kNeonTexto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              const Spacer(),
              if (yo != null && lista != null)
                Text('Tuyos: $mios', style: const TextStyle(color: kTenue, fontSize: 12)),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: kTenue, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          if (lista == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: kNeon, strokeWidth: 2)),
            )
          else if (lista != null && lista.isEmpty)
            const Text('Sé el primero en comentar.', style: TextStyle(color: kTenue))
          else if (lista != null)
            for (final c in lista) _burbuja(c, propio: c.autorId == yo?.uid, puedeBorrar: c.autorId == yo?.uid || sesion.esAdmin),
          const SizedBox(height: 14),
          if (yo == null)
            OutlinedButton.icon(
              onPressed: () => EntrarScreen.abrir(context),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Inicia sesión para comentar'),
            )
          else
            _caja(yo),
        ],
      ),
    );
  }

  Widget _burbuja(Comentario c, {required bool propio, required bool puedeBorrar}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: propio ? const Color(0x33E94560) : kSuperficie,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${propio ? 'Tú' : c.autor} · ${horaCorta(c.hora)} ${_dia(c.hora)}',
                  style: TextStyle(color: propio ? kNeonTexto : kTenue, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(c.texto, style: const TextStyle(color: kTexto, height: 1.4)),
              ],
            ),
          ),
          if (puedeBorrar)
            IconButton(
              tooltip: 'Borrar comentario',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, color: kTenue, size: 18),
              onPressed: () => _borrar(c),
            ),
        ],
      ),
    );
  }

  Widget _caja(Cuenta yo) {
    final largo = _texto.text.trim().length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _texto,
          minLines: 1,
          maxLines: 4,
          style: const TextStyle(color: kTexto),
          decoration: campo(
            'Comentar como ${yo.apodo}',
            error: _errorEnvio,
            ayuda: '$largo/${ReglasComentario.maxTexto}',
            sufijo: _enviando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kNeon)),
                  )
                : IconButton(
                    tooltip: 'Publicar',
                    icon: const Icon(Icons.send, color: kNeon),
                    onPressed: _enviar,
                  ),
          ),
        ),
      ],
    );
  }

  static String _dia(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
